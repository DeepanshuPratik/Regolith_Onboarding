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
using Gtk;

namespace linux_onboarding {

    /**
     * sway, and i3 alongside it.
     *
     * One platform for two window managers because they share the whole of the
     * mechanism this directory implements — the same binding-mode config syntax,
     * the same IPC event stream, the same config.d layout — and differ only in
     * the name of the client binary and in whether the config can be queried
     * back. A second directory would be a copy of this one with two strings
     * changed.
     *
     * Offers no window placer. Placement under sway is a Wayland layer-shell
     * question, not a sway one, so it comes from src/platforms/wayland/ and this
     * platform leaves it null rather than duplicating it.
     */
    public class SwayPlatform : GLib.Object, Platform {

        // Resolved once when the platform is built: which of the two is running.
        private string wm_id = "";
        private string ipc = "";

        public SwayPlatform () {
            // Set-but-empty is not a session: `env SWAYSOCK= app` would
            // otherwise make this platform claim a KDE or GNOME session and
            // answer for a window manager that is not running.
            if (has_socket ("SWAYSOCK")) {
                wm_id = "sway";
                ipc = "swaymsg";
            } else if (has_socket ("I3SOCK")) {
                wm_id = "i3";
                ipc = "i3-msg";
            }
        }

        private static bool has_socket (string name) {
            var value = Environment.get_variable (name);
            return value != null && value.strip () != "";
        }

        public string id () { return "sway"; }

        public bool claims_session () { return wm_id != ""; }

        public SessionProbe? probe () { return new SwayProbe (wm_id); }

        public bool can_observe () { return true; }

        public ShortcutObserver? observer (Gtk.Widget owner) {
            return new SwayObserver (ipc, wm_id);
        }

        public BindingResolver? resolver () { return new SwayResolver (wm_id); }

        /**
         * Only pairs with our own observer. A foreign one may be holding an input
         * grab this platform knows nothing about, and a synthesized keystroke sent
         * while a grab is held comes straight back to our own window — so
         * declining is safer than dispatching blind. It happens when a sway
         * session falls back to the seat grab because the binding mode would not
         * install.
         */
        public ActionDispatcher? dispatcher (ShortcutObserver observer) {
            if (!(observer is SwayObserver)) return null;
            return new SwayDispatcher (new SwayResolver (wm_id));
        }

        public void cleanup_stale_state () {
            SwayModes.cleanup_stale_state (ipc, wm_id);
        }

        /**
         * The mode file, and the command that leaves the mode.
         *
         * Both matter: removing the file is not enough, because sway keeps the
         * config it has already loaded — a crash while the mode is active
         * leaves the compositor in it, with every key the app named bound to
         * `nop`. The IPC binary is resolved to an absolute path here, at
         * startup, because a signal handler may not search PATH.
         */
        public void collect_emergency_reset (EmergencyReset into) {
            foreach (var path in SwayModes.mode_file_candidates (wm_id))
                into.add_file (path);

            var binary = Environment.find_program_in_path (ipc);
            if (binary != null) into.set_command ({ binary, "mode", "default", null });
        }
    }

    /**
     * The default session facts, plus the one thing this platform knows that
     * shared code deliberately does not: the name of the window manager.
     *
     * This override is the entire cost of teaching the app about a new window
     * manager. Nothing outside this directory names sway or i3.
     */
    private class SwayProbe : DefaultSessionProbe {

        private string wm_id;

        public SwayProbe (string wm_id) { this.wm_id = wm_id; }

        public override string window_manager () { return wm_id; }
    }
}
