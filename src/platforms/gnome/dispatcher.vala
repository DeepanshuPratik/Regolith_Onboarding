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
     * Performs a step's action on GNOME by replaying the keystroke and letting
     * Mutter act on it as usual.
     *
     * Always synthesis, never a command. GNOME has no counterpart to `swaymsg` —
     * nothing that takes an action name and performs it — so although
     * GnomeResolver can say that a key is bound to `terminal`, that name is an
     * identifier and not something runnable. bound_command is therefore ignored
     * here; it stays in the signature because it is the contract's, exactly as
     * on X11.
     *
     * The grab dance around the replay is the point of this class, and it is not
     * redundant with the observer's own start/stop. Spike #11 measured what
     * happens without it: a keyboard-only seat grab makes GTK request
     * zwp_keyboard_shortcuts_inhibit_v1, Mutter honours it with no carve-out for
     * Super, and keys ydotool injects at the evdev level are then delivered
     * straight back to *us* instead of being acted on by the compositor. The
     * shortcut the user just practised would visibly do nothing. So the grab has
     * to be dropped for the length of the replay and taken back afterwards, and
     * only the observer holding it can do either — which is why this is
     * constructed around one rather than working alone.
     *
     * A caveat #11 also established, recorded here because it decides what
     * happens next rather than what happens in this method: on Mutter the
     * re-grab is inert once focus has actually left, and the request returns
     * SUCCESS regardless. Recovery on GNOME is therefore the user coming back to
     * the window, not anything this class can do. retake_grab() is still the
     * right call — it is correct whenever focus never left, which is the common
     * case for a shortcut that does not raise a window.
     */
    public class GnomeDispatcher : GLib.Object, ActionDispatcher {

        private SeatGrabObserver observer;
        private KeySynthesizer synth = new KeySynthesizer ();

        public GnomeDispatcher (SeatGrabObserver observer) {
            this.observer = observer;
        }

        /**
         * False when neither synthesis tool is installed.
         *
         * Answered honestly rather than optimistically, because synthesis is the
         * only route here: with no tool there is nothing to fall back to, and a
         * dispatcher that claimed to work would leave the user watching a step
         * complete while their desktop did nothing. KeySynthesizer picks between
         * the two by the same test — ydotool on Wayland, xdotool otherwise — so
         * this checks for both rather than guessing which it will choose.
         */
        public bool available () {
            return GLib.Environment.find_program_in_path ("ydotool") != null
                || GLib.Environment.find_program_in_path ("xdotool") != null;
        }

        public string unavailable_reason () {
            return available () ? ""
                : "Neither ydotool nor xdotool is installed, so shortcuts cannot be performed for you on GNOME.";
        }

        public bool dispatch (string key_id, string? bound_command) {
            if (!available ()) return false;

            observer.release_grab ();
            Posix.system (synth.command_for (key_id));
            observer.retake_grab ();
            return true;
        }
    }
}
