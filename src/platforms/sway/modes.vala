/****************************************************************************************
 * Copyright (c) 2023 Deepanshu Pratik <deepanshu.pratik@gmail.com>                     *
 *                                                                                      *
 * This program is free software; you can redistribute it and/or modify it under        *
 * the terms of the Apache License as published by the Free Software                    *
 * Foundation; either version 2 of the License, or (at your option) any later           *
 * version.                                                                             *
 *                                                                                      *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY      *
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A      *
 * PARTICULAR PURPOSE. See the Apache License for more details.                         *
 *                                                                                      *
 * You should have received a copy of the Apache License along with this program.       *
 *  If not, see <http://www.apache.org/licenses/>.                                      *
 ****************************************************************************************/

namespace linux_onboarding {

    /**
     * The binding mode the sway observer installs, and the file in config.d that
     * carries it.
     *
     * Deliberately not one of the five services (D2): a binding mode is how this
     * one family of window managers happens to make observation possible, not a
     * capability any other desktop would implement. Keeping it a plain class
     * private to src/platforms/sway/ means the contracts never grow a concept
     * only sway has.
     *
     * The mode binds every key we care about to `nop`, so pressing one fires an
     * IPC event we can see without the WM performing its usual action — which is
     * what lets us decide when to perform it ourselves.
     *
     * This writes to the user's config, so it is the one part of the platform
     * that outlives the process. Everything it writes it must be able to find
     * and delete again on a later run; see cleanup_stale_state().
     */
    public class SwayModes : GLib.Object {

        public const string MODE_NAME = "Onboarding";
        private const string MODE_FILE = "linux_onboarding_mode";
        private const string LEGACY_MODE_FILE = "regolith_onboarding_mode";

        // Which sway-family WM to talk to: "swaymsg" or "i3-msg", and "sway" or
        // "i3" for the config.d path. Passed in rather than detected, because the
        // platform already worked it out when it claimed the session.
        private string ipc;
        private string wm_id;

        private string mode_file_path = "";

        public SwayModes (string ipc, string wm_id) {
            this.ipc = ipc;
            this.wm_id = wm_id;
        }

        // swaymsg prints a JSON acknowledgement for every command; capture it so it
        // does not leak into our own stdout.
        public void wm_command (string args) {
            try {
                string ack;
                Process.spawn_command_line_sync (ipc + " " + args, out ack, null, null);
            } catch (Error e) {
                stderr.printf ("%s %s: %s\n", ipc, args, e.message);
            }
        }

        /** Switch the WM into our mode, so the nop bindings are the live ones. */
        public void enter () { wm_command ("mode '" + MODE_NAME + "'"); }

        /** Hand the keyboard back to the user's own bindings. */
        public void leave () { wm_command ("mode default"); }

        /**
         * Write the mode block for every key in these workflows and reload the WM.
         *
         * One block for all of them, not one per workflow: matching is done in
         * process by the observer, so a wider mode only means seeing events we
         * already ignore, while a mode per workflow would multiply both the config
         * text and the escaping burden for no behavioural gain.
         *
         * Each `bindsym` line is built from a workflow `key_id`, which can arrive
         * from a marketplace repository via a hand-placed file. The mode block is
         * written to the user's `config.d` and reloaded by sway, so anything that
         * can terminate the block can inject arbitrary sway config that the WM
         * then executes. The sanitiser (sanitise_key_id) is what stops that: a
         * `key_id` containing a newline plus `}` closes the block; one that
         * contains just a `}` does the same; one with a stray `"` confuses the
         * surrounding mode-string parsing on the next reload. All of them are
         * rejected, and the workflow is skipped, before the line is ever written.
         *
         * A sanitiser rejecting a key it cannot prove safe is the only honest
         * answer. Writing a "best-effort" line and crossing our fingers is the
         * exact class of bug the parser bugs in #18 surfaced: a key reported as
         * bound to something it is not, or a config line that looks fine and
         * silently invalidates the whole block.
         */
        public bool install (Gee.List<Workflow> workflows) {
            var config_d = find_or_create_config_d ();
            if (config_d == null) return false;
            mode_file_path = Path.build_filename (config_d, MODE_FILE);

            var block = new StringBuilder ();
            block.append ("mode \"" + MODE_NAME + "\" {\n");
            int rejected = 0;
            foreach (var workflow in workflows) {
                var steps = workflow.steps;
                for (int i = 0; i < (int) steps.get_length (); i++) {
                    var element = steps.get_element (i);
                    if (element == null || element.get_node_type () != Json.NodeType.OBJECT) continue;
                    var step = element.get_object ();
                    if (!step.has_member ("key_id")) continue;

                    string key_id = step.get_string_member ("key_id");
                    string key;
                    string? reason = sanitise_key_id_for_mode (key_id, out key);
                    if (reason != null) {
                        stderr.printf ("Skipping unsafe workflow key %s in '%s': %s\n",
                                       key_id, workflow.name, reason);
                        rejected++;
                        continue;
                    }
                    block.append ("    bindsym " + key + " nop\n");
                }
            }
            // Always bindable, so the user can back out from inside the mode.
            block.append ("    bindsym Escape nop\n");
            block.append ("}\n");

            try {
                var f = File.new_for_path (mode_file_path);
                var w = new DataOutputStream (f.replace (null, false, FileCreateFlags.NONE));
                w.put_string (block.str);
                w.close ();
            } catch (Error e) {
                stderr.printf ("Failed to write mode file: %s\n", e.message);
                return false;
            }

            try {
                string ack;
                Process.spawn_command_line_sync (ipc + " reload", out ack, null, null);
            } catch (Error e) {
                stderr.printf ("WM reload failed: %s\n", e.message);
                uninstall ();
                return false;
            }

            // Give the WM a moment to finish the reload before the caller subscribes.
            // Sway is not synchronous: a `reload` that has returned can still have
            // the mode block unprocessed when the next event arrives, and a
            // `mode enter` sent during that window gets reset back to "default".
            // The cost is paid once at startup, before the window is even shown,
            // so it is invisible to the user — which is the whole reason the
            // install-time reload moved here from per-workflow PLAY (#13).
            GLib.Thread.usleep (200 * 1000);

            if (rejected > 0) {
                // Loud, not silent: a marketplace workflow with a bad key is a
                // supply-chain problem the user should know about, not a quiet
                // skip we let them discover when a step never matches.
                stderr.printf ("Installed mode with %d workflow key(s) rejected. " +
                               "Run --check-workflows to see the offending steps.\n",
                               rejected);
            }
            return true;
        }

        // The bindsym-line sanitiser is in src/keys/sanitise.vala, alongside
        // the KeySpec parser it composes with. Keeping it there means the
        // security-critical path is testable without a running sway.

        /** Where the block was written, for the log. Empty when nothing is installed. */
        public string installed_at () { return mode_file_path; }

        public void uninstall () {
            if (mode_file_path == "") return;
            try { File.new_for_path (mode_file_path).delete (); } catch {}
            mode_file_path = "";
            wm_command ("reload");
        }

        // Returns the first config.d that exists, Regolith layout first, creating
        // the preferred one if the user has none yet.
        private string? find_or_create_config_d () {
            var home = Environment.get_home_dir ();
            string[] candidates = {
                Path.build_filename (home, ".config", "regolith3", wm_id, "config.d"),
                Path.build_filename (home, ".config", "regolith2", wm_id, "config.d"),
                Path.build_filename (home, ".config", wm_id, "config.d"),
            };
            foreach (var dir in candidates) {
                if (FileUtils.test (dir, FileTest.IS_DIR)) return dir;
            }
            try {
                File.new_for_path (candidates[0]).make_directory_with_parents ();
                return candidates[0];
            } catch (Error e) {
                stderr.printf ("Cannot find or create config.d: %s\n", e.message);
                return null;
            }
        }

        /**
         * Safety net for quitting mid-practice. If the app is killed or the user
         * hits Escape at the window level, uninstall() may never run and the mode
         * block would be left behind in config.d, permanently shadowing those keys.
         *
         * Static and path-driven rather than working through an instance, because
         * the run that has to clean up is usually not the run that made the mess.
         */
        public static void cleanup_stale_state (string ipc, string wm_id) {
            string ack;
            try { Process.spawn_command_line_sync (ipc + " mode default", out ack, null, null); } catch {}

            var home = Environment.get_home_dir ();
            string[] roots = { "regolith3", "regolith2", null };
            // LEGACY_MODE_FILE is the pre-rename name; clear it too so upgrades do
            // not strand a block written by an older build.
            string[] names = { MODE_FILE, LEGACY_MODE_FILE };

            bool deleted = false;
            foreach (var root in roots) {
                foreach (var name in names) {
                    var path = (root == null)
                        ? Path.build_filename (home, ".config", wm_id, "config.d", name)
                        : Path.build_filename (home, ".config", root, wm_id, "config.d", name);
                    if (!FileUtils.test (path, FileTest.EXISTS)) continue;
                    try { File.new_for_path (path).delete (); deleted = true; } catch {}
                }
            }
            if (deleted) {
                try { Process.spawn_command_line_sync (ipc + " reload", out ack, null, null); } catch {}
            }
        }
    }
}
