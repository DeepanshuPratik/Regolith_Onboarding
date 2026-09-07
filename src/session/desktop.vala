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
     * The session facts nobody has to be a platform to read: which desktop
     * environment announced itself, and whether we are on Wayland.
     *
     * The desktop identity drives which set of workflows is loaded. Distros
     * report it through XDG_CURRENT_DESKTOP, which is a colon-separated list in
     * descending specificity — Regolith sets "Regolith-Wayland:GNOME:sway".
     *
     * Deliberately no longer answers "which window manager is this". That
     * question used to be a three-value enum here, which meant a new tiling WM
     * could not be recognised without editing this file — a central edit of
     * exactly the kind src/platforms/ exists to avoid. It now belongs to
     * whichever platform recognises the WM; see SessionProbe.window_manager().
     */
    public class Desktop : GLib.Object {

        private static Desktop? instance = null;

        public string raw_desktop { get; private set; }
        public bool   is_wayland  { get; private set; }

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

        /**
         * One line of session facts. Takes the window-manager id from the caller
         * rather than knowing one, because the facts here cannot name a WM any
         * more — the probe that is describing itself supplies that.
         */
        public string describe (string wm_id) {
            return "desktop=%s candidates=[%s] wayland=%s wm=%s".printf (
                raw_desktop.length > 0 ? raw_desktop : "<unset>",
                string.joinv (", ", candidates),
                is_wayland.to_string (),
                wm_id.length > 0 ? wm_id : "unknown");
        }
    }
}
