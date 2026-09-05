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
     * Capture for sway and i3.
     *
     * Writes a binding mode into the WM's config.d, which the distro config
     * includes automatically, then subscribes to binding events over IPC. Every
     * key we care about is bound to `nop` inside that mode, so pressing it fires
     * an event we can see without the WM performing its usual action — which lets
     * us decide when to perform it ourselves.
     *
     * This needs no input grab, so the rest of the desktop keeps working while a
     * workflow is in progress.
     */
    public class WmModeBackend : GLib.Object, CaptureBackend {

        private const string MODE_NAME = "Onboarding";
        private const string MODE_FILE = "linux_onboarding_mode";
        private const string LEGACY_MODE_FILE = "regolith_onboarding_mode";

        private WindowManager wm;
        private configManager cfg = new configManager ();

        private string mode_file_path = "";
        private Pid            ipc_pid      = 0;
        private GLib.IOChannel ipc_channel  = null;
        private uint           ipc_watch_id = 0;

        private string armed_spec = "";
        private bool   listening  = false;
        private bool   started    = false;

        public WmModeBackend (WindowManager wm) {
            this.wm = wm;
        }

        private string ipc () { return wm.ipc_command (); }

        // swaymsg prints a JSON acknowledgement for every command; capture it so it
        // does not leak into our own stdout.
        private void wm_command (string args) {
            try {
                string ack;
                Process.spawn_command_line_sync (ipc () + " " + args, out ack, null, null);
            } catch (Error e) {
                stderr.printf ("%s %s: %s\n", ipc (), args, e.message);
            }
        }

        public bool available () {
            return wm.is_tiling ();
        }

        public string unavailable_reason () {
            return available () ? ""
                : "Practice needs sway or i3; no compatible window manager was found.";
        }

        public bool start (Json.Array steps) {
            if (!available ()) return false;

            var config_d = find_or_create_config_d ();
            if (config_d == null) return false;
            mode_file_path = Path.build_filename (config_d, MODE_FILE);

            var block = new StringBuilder ();
            block.append ("mode \"" + MODE_NAME + "\" {\n");
            for (int i = 0; i < (int) steps.get_length (); i++) {
                var element = steps.get_element (i);
                if (element == null || element.get_node_type () != Json.NodeType.OBJECT) continue;
                var step = element.get_object ();
                if (!step.has_member ("key_id")) continue;
                var spec = cfg.format_spec_for_mode (step.get_string_member ("key_id"));
                if (spec == "") continue;
                block.append ("    bindsym " + spec + " nop\n");
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
                Process.spawn_command_line_sync (ipc () + " reload", out ack, null, null);
            } catch (Error e) {
                stderr.printf ("WM reload failed: %s\n", e.message);
                remove_mode_file ();
                return false;
            }

            // Give the WM a moment to finish the reload before subscribing.
            GLib.Thread.usleep (200 * 1000);

            try {
                int stdout_fd;
                string[] argv = { ipc (), "-t", "subscribe", "-m", "[\"binding\"]" };
                Process.spawn_async_with_pipes (
                    null, argv, null,
                    SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                    null, out ipc_pid, null, out stdout_fd, null);
                ipc_channel = new GLib.IOChannel.unix_new (stdout_fd);
            } catch (Error e) {
                stderr.printf ("IPC subscribe failed: %s\n", e.message);
                remove_mode_file ();
                return false;
            }

            ipc_watch_id = ipc_channel.add_watch (
                GLib.IOCondition.IN | GLib.IOCondition.HUP, on_ipc_event);

            debug_log ("installed mode '%s' at %s", MODE_NAME, mode_file_path);
            started = true;
            return true;
        }

        public void arm (string key_id) {
            armed_spec = cfg.format_spec_for_mode (key_id);
            listening = armed_spec != "";
            debug_log ("armed '%s' -> %s%s", key_id, armed_spec,
                       listening ? "" : "  (unmatchable, step cannot be captured)");

            // Deferred: sway can still be settling after the reload, and a mode
            // command sent too early gets reset back to "default".
            GLib.Timeout.add (300, () => {
                if (listening) wm_command ("mode '" + MODE_NAME + "'");
                return false;
            });
        }

        public void stop () {
            if (!started && mode_file_path == "") return;

            wm_command ("mode default");

            if (ipc_watch_id != 0) { GLib.Source.remove (ipc_watch_id); ipc_watch_id = 0; }
            if (ipc_channel != null) {
                try { ipc_channel.shutdown (false); } catch {}
                ipc_channel = null;
            }
            if (ipc_pid != 0) {
                Posix.kill ((Posix.pid_t) ipc_pid, Posix.Signal.TERM);
                ChildWatch.add (ipc_pid, (pid, status) => { Process.close_pid (pid); });
                ipc_pid = 0;
            }

            remove_mode_file ();
            listening = false;
            started = false;
        }

        public void dispatch (string key_id, string fallback_command) {
            var spec = cfg.format_spec_for_mode (key_id);
            if (execute_via_wm_binding (spec)) {
                debug_log ("dispatched '%s' via its real WM binding", spec);
            } else {
                debug_log ("no WM binding for '%s'; synthesizing: %s", spec, fallback_command);
                Posix.system (fallback_command);
            }
        }

        [PrintfFormat]
        private void debug_log (string format, ...) {
            stdout.printf ("capture: %s\n", format.vprintf (va_list ()));
        }

        private bool on_ipc_event (GLib.IOChannel src, GLib.IOCondition cond) {
            if ((cond & GLib.IOCondition.HUP) != 0) return false;

            try {
                string line;
                size_t length, term_pos;
                if (src.read_line (out line, out length, out term_pos) != GLib.IOStatus.NORMAL)
                    return true;
                if (line == null) return true;
                line = line.strip ();
                if (line.length == 0) return true;

                // Subscription acknowledgement: [{"success":true}]
                if (line.has_prefix ("[")) return true;
                if (!listening) return true;

                var parser = new Json.Parser ();
                parser.load_from_data (line);
                var root = parser.get_root ().get_object ();
                if (root.get_string_member ("change") != "run") return true;

                var binding = root.get_object_member ("binding");
                var sym_node = binding.get_member ("symbol");
                if (sym_node == null || sym_node.is_null ()) return true;
                var symbol = sym_node.get_string ();

                if (symbol == "Escape") {
                    listening = false;
                    aborted ();
                    return true;
                }

                if (armed_spec == "") return true;
                if (!event_matches (armed_spec, symbol, binding.get_array_member ("event_state_mask"))) {
                    debug_log ("saw '%s', waiting for '%s'", symbol, armed_spec);
                    return true;
                }
                debug_log ("matched '%s'", armed_spec);

                // Stop matching immediately: the caller runs an animation before
                // arming the next step, and a repeat press must not slip through.
                listening = false;
                wm_command ("mode default");
                step_matched ();

            } catch (Error e) {
                stderr.printf ("IPC event error: %s\n", e.message);
            }
            return true;
        }

        // True when a sway binding event matches a spec such as "Mod4+Return".
        private bool event_matches (string expected, string symbol, Json.Array mask) {
            var parts = expected.split ("+");
            // The WM reports the canonical keysym name, which differs in case
            // from what a config file may have been written with.
            if (symbol.down () != parts[parts.length - 1].down ()) return false;

            int expected_mods = parts.length - 1;
            if (expected_mods != (int) mask.get_length ()) return false;

            for (int i = 0; i < expected_mods; i++) {
                var actual = mask.get_element (i).get_string ().down ();
                bool found = false;
                for (int j = 0; j < expected_mods; j++) {
                    if (parts[j].down () == actual) { found = true; break; }
                }
                if (!found) return false;
            }
            return true;
        }

        // Returns the first config.d that exists, Regolith layout first, creating
        // the preferred one if the user has none yet.
        private string? find_or_create_config_d () {
            var home = Environment.get_home_dir ();
            var wm_dir = wm.to_id ();
            string[] candidates = {
                Path.build_filename (home, ".config", "regolith3", wm_dir, "config.d"),
                Path.build_filename (home, ".config", "regolith2", wm_dir, "config.d"),
                Path.build_filename (home, ".config", wm_dir, "config.d"),
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
         * hits Escape at the window level, stop() may never run and the mode block
         * would be left behind in config.d, permanently shadowing those keys.
         */
        public static void cleanup_stale_state () {
            var wm = Desktop.get_default ().wm;
            if (!wm.is_tiling ()) return;

            var ipc = wm.ipc_command ();
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
                        ? Path.build_filename (home, ".config", wm.to_id (), "config.d", name)
                        : Path.build_filename (home, ".config", root, wm.to_id (), "config.d", name);
                    if (!FileUtils.test (path, FileTest.EXISTS)) continue;
                    try { File.new_for_path (path).delete (); deleted = true; } catch {}
                }
            }
            if (deleted) {
                try { Process.spawn_command_line_sync (ipc + " reload", out ack, null, null); } catch {}
            }
        }

        private void remove_mode_file () {
            if (mode_file_path == "") return;
            try { File.new_for_path (mode_file_path).delete (); } catch {}
            mode_file_path = "";
            wm_command ("reload");
        }

        /**
         * Finds what key_spec is really bound to and runs that command directly.
         *
         * Scans the WM config for a matching `bindsym`, resolving $variables from
         * the main config files (where they are defined) before comparing. Falls
         * back to the caller's synthesized keypress when nothing matches.
         *
         * sway only — i3 keeps no equivalent queryable config, so it takes the
         * synthesized-keypress path.
         */
        private bool execute_via_wm_binding (string key_spec) {
            if (wm != WindowManager.SWAY || key_spec.length == 0) return false;

            string home = Environment.get_home_dir ();
            var vars = new GLib.Array<string> ();
            var all = new StringBuilder ();

            // $mod and friends live in the main config, not in config.d.
            string[] main_configs = {
                "/etc/regolith/sway/config",
                "/usr/share/regolith/sway/config",
                "/usr/share/regolith/common/sway/config",
                Path.build_filename (home, ".config", "regolith3", "sway", "config"),
                Path.build_filename (home, ".config", "sway", "config"),
            };
            foreach (var src in main_configs) {
                string contents = "";
                try { FileUtils.get_contents (src, out contents); } catch { continue; }
                foreach (var line in contents.split ("\n"))
                    parse_var_line (line.strip (), vars);
                all.append ("\n");
                all.append (contents);
            }

            // Whatever sway actually last loaded, which may differ from the files.
            string cfg_json = "";
            try { Process.spawn_command_line_sync ("swaymsg -t get_config", out cfg_json, null, null); } catch {}
            if (cfg_json.length > 0) {
                string main_cfg = "";
                try {
                    var p = new Json.Parser ();
                    p.load_from_data (cfg_json);
                    main_cfg = p.get_root ().get_object ().get_string_member ("config");
                } catch { main_cfg = cfg_json; }
                foreach (var line in main_cfg.split ("\n"))
                    parse_var_line (line.strip (), vars);
                all.append ("\n");
                all.append (main_cfg);
            }

            string[] search_dirs = {
                "/usr/share/regolith/common/config.d",
                "/usr/share/regolith/sway/config.d",
                "/etc/regolith3/sway/config.d",
                Path.build_filename (home, ".config", "regolith3", "common-wm", "config.d"),
                Path.build_filename (home, ".config", "regolith3", "sway", "config.d"),
                Path.build_filename (home, ".config", "regolith2", "sway", "config.d"),
                Path.build_filename (home, ".config", "sway", "config.d"),
            };
            foreach (var dir in search_dirs) {
                if (!FileUtils.test (dir, FileTest.IS_DIR)) continue;
                try {
                    var d = Dir.open (dir, 0);
                    string? fn;
                    while ((fn = d.read_name ()) != null) {
                        string contents = "";
                        try {
                            FileUtils.get_contents (Path.build_filename (dir, fn), out contents);
                            all.append ("\n");
                            all.append (contents);
                        } catch {}
                    }
                } catch {}
            }

            string[] lines = all.str.split ("\n");
            // config.d fragments can define variables of their own.
            foreach (var line in lines)
                parse_var_line (line.strip (), vars);

            // Only top-level bindsyms; ones nested in a mode block are not active.
            int depth = 0;
            foreach (var line in lines) {
                var s = line.strip ();
                if (s.has_suffix ("{")) { depth++; continue; }
                if (s == "}") { if (depth > 0) depth--; continue; }
                if (depth != 0 || !s.has_prefix ("bindsym ")) continue;

                string resolved = resolve_vars (s, vars);

                string rest = resolved.substring ("bindsym ".length).strip ();
                while (rest.has_prefix ("--")) {          // --no-warn, --locked, ...
                    int flag_end = rest.index_of (" ");
                    if (flag_end < 0) { rest = ""; break; }
                    rest = rest.substring (flag_end).strip ();
                }
                if (rest.length == 0) continue;
                int sp = rest.index_of (" ");
                if (sp < 0) continue;

                string bound_key = rest.substring (0, sp).strip ();
                string bound_cmd = rest.substring (sp).strip ();

                if (!keys_match (bound_key, key_spec)) continue;
                if (bound_cmd == "nop" || bound_cmd.length == 0) return true;

                try {
                    string[] argv = { "swaymsg", bound_cmd };
                    Process.spawn_sync (null, argv, null, SpawnFlags.SEARCH_PATH,
                                        null, null, null, null);
                    return true;
                } catch (Error e) {
                    stderr.printf ("swaymsg dispatch: %s\n", e.message);
                    return false;
                }
            }

            return false;
        }

        /**
         * Collects `set` and `set_from_resource` definitions.
         *
         * For set_from_resource we take the shipped default rather than querying
         * xrdb, which is not reliable on Wayland. Note these lines are column-aligned
         * in the Regolith configs ("set_from_resource $mod  wm.mod Mod4"), so the
         * fields must be split on runs of whitespace — splitting on a single space
         * yields an empty token and shifts the default value out of position.
         */
        private void parse_var_line (string raw, GLib.Array<string> into) {
            var s = raw.replace ("\t", " ");

            if (s.has_prefix ("set_from_resource ")) {
                // set_from_resource $name resource_key default_value
                var parts = tokenize (s);
                if (parts.length >= 4 && parts[1].has_prefix ("$")) {
                    into.append_val (parts[1]);
                    into.append_val (unquote (parts[3]));
                }
            } else if (s.has_prefix ("set ")) {
                // set $name value   — the value may itself contain spaces
                var parts = tokenize (s);
                if (parts.length >= 3 && parts[1].has_prefix ("$")) {
                    int after_name = s.index_of (parts[1]) + parts[1].length;
                    into.append_val (parts[1]);
                    into.append_val (unquote (s.substring (after_name).strip ()));
                }
            }
        }

        private static string[] tokenize (string s) {
            string[] parts = {};
            foreach (var t in s.split (" ")) {
                var trimmed = t.strip ();
                if (trimmed.length > 0) parts += trimmed;
            }
            return parts;
        }

        private static string unquote (string s) {
            if (s.length >= 2 && s.has_prefix ("\"") && s.has_suffix ("\""))
                return s.substring (1, s.length - 2);
            return s;
        }

        /**
         * Substitutes $variables into a config line, longest name first.
         *
         * Order matters: Regolith defines both $ws1 and $ws10, and replacing the
         * shorter name first would rewrite "$ws10" into the value of $ws1 followed
         * by a stray "0".
         */
        private string resolve_vars (string line, GLib.Array<string> vars) {
            int count = (int) vars.length / 2;
            if (count == 0) return line;

            int[] order = new int[count];
            for (int i = 0; i < count; i++) order[i] = i;
            for (int i = 1; i < count; i++) {
                int key = order[i];
                int j = i - 1;
                while (j >= 0 && vars.index (order[j] * 2).length < vars.index (key * 2).length) {
                    order[j + 1] = order[j];
                    j--;
                }
                order[j + 1] = key;
            }

            string result = line;
            foreach (var idx in order)
                result = result.replace (vars.index (idx * 2), vars.index (idx * 2 + 1));
            return result;
        }

        // Modifier order and case are irrelevant: "Mod4+Shift+Return" == "shift+mod4+Return"
        private bool keys_match (string a, string b) {
            return sort_key_spec (a.down ()) == sort_key_spec (b.down ());
        }

        private string sort_key_spec (string key_spec) {
            var parts = key_spec.split ("+");
            if (parts.length <= 1) return key_spec;

            string symbol = parts[parts.length - 1];
            string[] mods = {};
            for (int i = 0; i < parts.length - 1; i++) mods += parts[i];
            for (int i = 1; i < mods.length; i++) {
                string key = mods[i];
                int j = i - 1;
                while (j >= 0 && mods[j] > key) { mods[j + 1] = mods[j]; j--; }
                mods[j + 1] = key;
            }
            return string.joinv ("+", mods) + "+" + symbol;
        }
    }
}
