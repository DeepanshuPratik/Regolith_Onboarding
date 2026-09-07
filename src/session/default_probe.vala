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
     * The SessionProbe used when no platform supplies one of its own, and the
     * base class the ones that do are built from.
     *
     * Everything here reads Desktop's XDG facts, which hold regardless of which
     * desktop is running. The one question it deliberately answers with a shrug
     * is window_manager(): this probe recognises no window manager at all,
     * because recognising one is a platform's job.
     *
     * A platform that drives a WM subclasses this and overrides that single
     * method. That is the whole of the fix for the seam #9 flagged. It used to
     * be a three-value enum, with an if-chain over SWAYSOCK / I3SOCK sitting in
     * shared code, so Hyprland could not be reported without a central edit; now
     * a Hyprland platform ships src/platforms/hyprland/platform.vala carrying
     * its own probe, checking its own environment variable, returning its own
     * id, and nothing outside that directory changes.
     *
     * The id became a free string for the same reason. An enum is a closed set
     * only the file declaring it can extend, and its exhaustiveness bought
     * nothing here: every caller either prints the id or compares it against a
     * literal it already knows.
     */
    public class DefaultSessionProbe : GLib.Object, SessionProbe {

        protected Desktop facts = Desktop.get_default ();

        /**
         * Always true. This probe is the last entry in the registry's list, and
         * a last resort that could decline would leave callers with no probe at
         * all — while every answer it gives is valid on any session.
         */
        public bool claims_session () { return true; }

        public bool is_wayland () { return facts.is_wayland; }

        /**
         * Empty: no window manager we can drive. Overridden by the platform that
         * recognises one, and by nothing else.
         */
        public virtual string window_manager () { return ""; }

        public string[] desktop_candidates () { return facts.candidates; }

        /**
         * Overrides the contract's generic one-liner so the startup log and
         * --check-workflows keep printing the raw XDG_CURRENT_DESKTOP string
         * beside the normalised candidates. When a distro announces itself in a
         * way we mis-normalise, the raw value is the only thing that shows it.
         */
        public string describe () {
            return facts.describe (window_manager ());
        }
    }
}
