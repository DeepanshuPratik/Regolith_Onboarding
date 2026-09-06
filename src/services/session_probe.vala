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
     * The session facts every other service branches on: whether this is
     * Wayland, which desktop's workflows apply, and whether there is a window
     * manager we can hold a conversation with.
     *
     * These are a contract rather than a single class because detection is the
     * part a distro is most likely to know better than we do. The default probe
     * reads XDG_CURRENT_DESKTOP, XDG_SESSION_TYPE and the WM socket variables,
     * which is correct for the desktops shipped here and wrong for any distro
     * that announces itself some other way. Such a distro supplies its own probe
     * rather than adding a case to a switch in the middle of this tree.
     *
     * Lifecycle: none. Everything a probe reports is fixed for the life of the
     * process, so a caller may resolve one at startup and hold it. There is
     * deliberately no start/stop and no window argument — the --check-workflows
     * path asks these questions with no display connection at all, so no answer
     * may depend on a realised widget.
     */
    public interface SessionProbe : GLib.Object {

        /**
         * Whether this probe recognises the running session.
         *
         * Deliberately NOT called available(), unlike the other four contracts.
         * Theirs is a capability question the UI may have to explain to the user
         * — "practice does not work on this desktop". This one is a selection
         * fact the registry asks while choosing a platform, and the user never
         * sees it. Giving both the same name would invite a caller to treat a
         * probe that does not apply as a desktop that cannot do something, which
         * are unrelated conditions.
         *
         * A probe answering false is describing some other desktop and its
         * remaining answers carry no weight; ask a different one.
         */
        public abstract bool claims_session ();

        /**
         * Whether we are talking to a Wayland compositor.
         *
         * Not the same question as "is the session Wayland": GDK_BACKEND=x11
         * puts us on XWayland inside a Wayland compositor, where the X11 code
         * paths are the correct ones. A probe answers for the connection we
         * actually hold, not for the session type the login manager set.
         */
        public abstract bool is_wayland ();

        /**
         * The window manager we can drive directly, or UNKNOWN when there is
         * none we understand. Callers must check is_tiling() before trusting
         * anything derived from it.
         */
        public abstract WindowManager window_manager ();

        /**
         * Normalised desktop ids in descending specificity, always ending in
         * Desktop.FALLBACK_ID so the array is never empty and a walk over it
         * always terminates. Regolith yields
         * { "regolith", "gnome", "sway", "default" }.
         *
         * The whole list, not just the winner, is the contract: workflow lookup
         * walks it and takes the first directory that exists, which is what lets
         * a distro inherit its parent desktop's workflows by shipping none.
         */
        public abstract string[] desktop_candidates ();

        /**
         * The most specific desktop id. Derived, so a probe gets it for free
         * once it answers desktop_candidates() correctly.
         */
        public virtual string primary_desktop () {
            return desktop_candidates ()[0];
        }

        /** One line of session facts, for the startup log and --check-workflows. */
        public virtual string describe () {
            return "desktop=[%s] wayland=%s wm=%s".printf (
                string.joinv (", ", desktop_candidates ()),
                is_wayland ().to_string (),
                window_manager ().to_id ());
        }
    }
}
