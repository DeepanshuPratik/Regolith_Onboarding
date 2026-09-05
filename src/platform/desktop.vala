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

    // Window managers this application knows how to drive directly.
    public enum WindowManager {
        SWAY,
        I3,
        UNKNOWN;

        // Name of the IPC client binary for this WM. Callers must check
        // is_tiling() first; UNKNOWN has no meaningful command.
        public string ipc_command () {
            switch (this) {
                case SWAY: return "swaymsg";
                case I3:   return "i3-msg";
                default:   return "";
            }
        }

        public string to_id () {
            switch (this) {
                case SWAY: return "sway";
                case I3:   return "i3";
                default:   return "unknown";
            }
        }

        public bool is_tiling () {
            return this == SWAY || this == I3;
        }
    }

    /**
     * Session facts resolved once at startup: which desktop environment we are
     * running under, whether this is Wayland, and which window manager (if any)
     * we can talk to.
     *
     * The desktop identity drives which set of workflows is loaded. Distros
     * report it through XDG_CURRENT_DESKTOP, which is a colon-separated list in
     * descending specificity — Regolith sets "Regolith-Wayland:GNOME:sway".
     */
    public class Desktop : GLib.Object {

        private static Desktop? instance = null;

        public string raw_desktop { get; private set; }
        public bool   is_wayland  { get; private set; }
        public WindowManager wm   { get; private set; }

        // Normalised desktop ids in priority order, always ending in "default".
        // "Regolith-Wayland:GNOME:sway" -> { "regolith", "gnome", "sway", "default" }
        public string[] candidates { get; private set; }

        public const string FALLBACK_ID = "default";

        public static Desktop get_default () {
            if (instance == null) instance = new Desktop ();
            return instance;
        }

        private Desktop () {
            raw_desktop = Environment.get_variable ("XDG_CURRENT_DESKTOP") ?? "";

            // GDK_BACKEND=x11 forces an XWayland session even inside a Wayland
            // compositor, in which case the X11 code paths are the correct ones.
            var session_type = Environment.get_variable ("XDG_SESSION_TYPE");
            var gdk_backend  = Environment.get_variable ("GDK_BACKEND");
            is_wayland = (session_type == "wayland") && (gdk_backend != "x11");

            if (Environment.get_variable ("SWAYSOCK") != null)      wm = WindowManager.SWAY;
            else if (Environment.get_variable ("I3SOCK") != null)   wm = WindowManager.I3;
            else                                                    wm = WindowManager.UNKNOWN;

            candidates = build_candidates (raw_desktop);
        }

        // Lowercases each token and strips the session-type suffix distros append
        // to the most specific entry, so "Regolith-Wayland" and "Regolith-X11" both
        // resolve to the same "regolith" workflow set.
        internal static string[] build_candidates (string raw) {
            string[] result = {};

            foreach (var token in raw.split (":")) {
                var id = token.strip ().down ();
                if (id.has_suffix ("-wayland"))   id = id.substring (0, id.length - "-wayland".length);
                else if (id.has_suffix ("-x11"))  id = id.substring (0, id.length - "-x11".length);
                if (id.length == 0) continue;

                bool seen = false;
                foreach (var existing in result) {
                    if (existing == id) { seen = true; break; }
                }
                if (!seen) result += id;
            }

            result += FALLBACK_ID;
            return result;
        }

        // The most specific desktop id, or "default" when XDG_CURRENT_DESKTOP is unset.
        public string primary {
            get { return candidates[0]; }
        }

        public string describe () {
            return "desktop=%s candidates=[%s] wayland=%s wm=%s".printf (
                raw_desktop.length > 0 ? raw_desktop : "<unset>",
                string.joinv (", ", candidates),
                is_wayland.to_string (),
                wm.to_id ());
        }
    }
}
