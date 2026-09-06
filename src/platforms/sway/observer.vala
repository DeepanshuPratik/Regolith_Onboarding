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
     * Observation for sway and i3.
     *
     * Installs a binding mode (SwayModes) and subscribes to the WM's binding
     * events over IPC. Every key in the mode is bound to `nop`, so a press
     * reaches us as an event without the WM doing its usual thing.
     *
     * This is the only observer here that needs no input grab, which is why the
     * registry prefers it: the rest of the desktop keeps working normally while a
     * workflow is in progress, and the user can still reach anything the app is
     * not currently asking about.
     */
    public class SwayObserver : GLib.Object, ShortcutObserver {

        private SwayModes modes;
        private KeySpec spec = new KeySpec ();

        private Pid            ipc_pid      = 0;
        private GLib.IOChannel ipc_channel  = null;
        private uint           ipc_watch_id = 0;

        private string armed_spec = "";
        private bool   listening  = false;
        private bool   installed  = false;
        private bool   started    = false;

        // "swaymsg" or "i3-msg", decided by the platform that built us.
        private string ipc;

        public SwayObserver (string ipc, string wm_id) {
            this.ipc = ipc;
            this.modes = new SwayModes (ipc, wm_id);
        }

        public bool available () { return true; }

        public string unavailable_reason () { return ""; }

        public bool install (Gee.List<Workflow> workflows) {
            if (!modes.install (workflows)) return false;
            debug_log ("installed mode '%s' at %s", SwayModes.MODE_NAME, modes.installed_at ());
            installed = true;
            return true;
        }

        public void uninstall () {
            if (!installed) return;
            modes.uninstall ();
            installed = false;
        }

        public bool start () {
            try {
                int stdout_fd;
                string[] argv = { ipc, "-t", "subscribe", "-m", "[\"binding\"]" };
                Process.spawn_async_with_pipes (
                    null, argv, null,
                    SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                    null, out ipc_pid, null, out stdout_fd, null);
                ipc_channel = new GLib.IOChannel.unix_new (stdout_fd);
            } catch (Error e) {
                stderr.printf ("IPC subscribe failed: %s\n", e.message);
                uninstall ();
                return false;
            }

            ipc_watch_id = ipc_channel.add_watch (
                GLib.IOCondition.IN | GLib.IOCondition.HUP, on_ipc_event);

            started = true;
            return true;
        }

        public void arm (string key_id) {
            armed_spec = spec.format_spec_for_mode (key_id);
            listening = armed_spec != "";
            debug_log ("armed '%s' -> %s%s", key_id, armed_spec,
                       listening ? "" : "  (unmatchable, step cannot be captured)");

            // Deferred: sway can still be settling after the reload, and a mode
            // command sent too early gets reset back to "default".
            GLib.Timeout.add (300, () => {
                if (listening) modes.enter ();
                return false;
            });
        }

        public void stop () {
            if (!started && !installed) return;

            modes.leave ();

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

            uninstall ();
            listening = false;
            started = false;
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
                modes.leave ();
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
    }
}
