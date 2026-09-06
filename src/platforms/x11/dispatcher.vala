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
     * Performs a step's action by replaying the keystroke through xdotool and
     * letting the window manager act on it as usual.
     *
     * There is no resolver on X11 — no equivalent of `swaymsg -t get_config` that
     * would tell us what a key is bound to — so any command handed down is
     * ignored and synthesis is the only route. bound_command stays in the
     * signature because it is the contract's, not because anything here can use
     * it.
     *
     * The grab dance around the synthesis is the whole reason this is a separate
     * class rather than a shared synthesizing dispatcher: the keys have to be
     * sent while the seat is released, and only the observer holding the grab can
     * release it.
     */
    public class X11Dispatcher : GLib.Object, ActionDispatcher {

        private SeatGrabObserver observer;
        private KeySynthesizer synth = new KeySynthesizer ();

        public X11Dispatcher (SeatGrabObserver observer) {
            this.observer = observer;
        }

        /**
         * Whether dispatch is actually possible here.
         *
         * False when xdotool is not installed. This used to return true
         * unconditionally, which was the exact dishonesty #16 asked every
         * dispatcher to avoid: on X11 synthesis is the only route, and with no
         * tool there is nothing to fall back to, so claiming to work would let
         * a user watch a step complete while their desktop did nothing.
         * GnomeDispatcher already checked; X11 now agrees.
         */
        public bool available () {
            return GLib.Environment.find_program_in_path ("xdotool") != null;
        }

        public string unavailable_reason () {
            return available () ? ""
                : "xdotool is not installed, so shortcuts cannot be performed for you on X11.";
        }

        public bool dispatch (string key_id, string? bound_command) {
            observer.release_grab ();
            Posix.system (synth.command_for (key_id));
            observer.retake_grab ();
            return true;
        }
    }
}
