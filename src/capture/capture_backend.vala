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
     * How a practice step's keypress gets noticed, and how the action that key
     * normally performs gets run.
     *
     * Desktops differ enough here that this cannot be one code path. A tiling WM
     * lets us install a binding mode and subscribe to its IPC, which is precise
     * and needs no input grab. Everywhere else we fall back to grabbing the seat
     * and reading GTK key events, which cannot see shortcuts the compositor
     * consumes first. GNOME and KDE currently support neither.
     *
     * Lifecycle, per workflow:
     *
     *     start(steps)                 once, before the first step
     *       arm(key_id)                once per step
     *       dispatch(key_id, cmd)      after a match, to perform the real action
     *     stop()                       once, on finish or cancel
     */
    public interface CaptureBackend : GLib.Object {

        /** Whether this backend can actually work in the current session. */
        public abstract bool available ();

        /** Shown to the user when available() is false. */
        public abstract string unavailable_reason ();

        /**
         * One-time setup for a whole workflow: install bindings, subscribe to
         * events, take grabs. Returns false if control could not be taken, in
         * which case the caller should try another backend.
         */
        public abstract bool start (Json.Array steps);

        /** Undo everything start() did. Must be safe to call more than once. */
        public abstract void stop ();

        /**
         * Begin listening for one step's key. key_id is the raw remontoire spec
         * straight out of the workflow JSON, e.g. "<><Shift> Enter" — each
         * backend translates it into whatever form it matches against.
         */
        public abstract void arm (string key_id);

        /**
         * Perform the action the key is really bound to. fallback_command is a
         * synthesized keypress (xdotool/ydotool) used when the backend cannot
         * resolve the action any other way.
         */
        public abstract void dispatch (string key_id, string fallback_command);

        /** The armed key was pressed. */
        public signal void step_matched ();

        /** The user asked to stop practising (Escape). */
        public signal void aborted ();
    }

    /** Chooses the capture strategy that suits the running session. */
    public class CaptureBackends : GLib.Object {

        public static CaptureBackend for_session (Gtk.Widget owner) {
            var backend = choose (owner);
            stdout.printf ("capture backend: %s (available=%s)\n",
                           backend.get_type ().name (), backend.available ().to_string ());
            return backend;
        }

        private static CaptureBackend choose (Gtk.Widget owner) {
            var desktop = Desktop.get_default ();

            // A tiling WM can intercept precisely via a binding mode, and needs
            // no input grab — always prefer it when one is reachable.
            if (desktop.wm.is_tiling ())
                return new WmModeBackend (desktop.wm);

            // On X11 the seat grab genuinely receives every key, so practice works.
            if (!desktop.is_wayland)
                return new SeatGrabBackend (owner);

            // A Wayland compositor with no IPC we understand: it consumes the
            // shortcuts before we ever see them.
            return new UnsupportedBackend ();
        }

        /**
         * Whether practice is possible at all here, answerable without building a
         * backend — the UI needs this before any workflow is opened, and
         * SeatGrabBackend's constructor has the side effect of hooking key events.
         */
        public static bool supported () {
            var desktop = Desktop.get_default ();
            return desktop.wm.is_tiling () || !desktop.is_wayland;
        }

        /** Why practice is unavailable, phrased for the user. */
        public static string unsupported_reason () {
            return new UnsupportedBackend ().unavailable_reason ();
        }

        /** Used when the preferred backend's start() fails part-way. */
        public static CaptureBackend fallback (Gtk.Widget owner) {
            return new SeatGrabBackend (owner);
        }
    }
}
