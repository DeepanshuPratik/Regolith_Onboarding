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

        public bool available () { return true; }

        public string unavailable_reason () { return ""; }

        public bool dispatch (string key_id, string? bound_command) {
            observer.release_grab ();
            Posix.system (synth.command_for (key_id));
            observer.retake_grab ();
            return true;
        }
    }
}
