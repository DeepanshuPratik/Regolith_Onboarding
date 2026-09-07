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
     * Placement on X11, where a client may still move and resize itself: shrink
     * to a card near the top of the screen for practice, and put the window back
     * exactly where it was afterwards.
     *
     * Reached by XWayland too, which is why it is worth saying that the
     * mechanism is genuine here and not a hopeful call into the void: #12
     * measured client-requested coordinates landing pixel-exactly under XWayland
     * on Mutter, verified externally with xwininfo.
     *
     * Remembering the rectangle is this class's job and not the caller's — the
     * contract hands out intents, not geometry, so there is no rectangle for a
     * caller to give back. It is read at the moment of the shrink rather than at
     * construction, because the window may still be settling into its centred
     * position when the placer is first built.
     */
    public class X11Placer : GLib.Object, WindowPlacer {

        // The shrunk card sits this far right of where the window started, which
        // keeps it clear of a terminal opening at the left edge.
        private const int PRACTICE_OFFSET_X = 300;
        private const int CARD_WIDTH = 200;
        private const int CARD_HEIGHT = 150;

        private Gtk.Window window;

        // The rectangle to put back, and whether there is anything to put back.
        // All four numbers, not just the x the old HandleScreenMode kept: the
        // contract says restore() returns the window to its size and position
        // "whatever that was", and recomputing a plausible-looking centre instead
        // is how the window used to come back somewhere it had never been.
        private int normal_x = 0;
        private int normal_y = 0;
        private int normal_width = 0;
        private int normal_height = 0;
        private bool shrunk = false;

        public X11Placer (Gtk.Window window) {
            this.window = window;
        }

        public bool available () { return true; }

        public string unavailable_reason () { return ""; }

        public bool shrink_for_practice () {
            // Idempotent, and load-bearing: a second shrink would record the
            // card's own rectangle as the normal one and strand the window there.
            if (shrunk) return true;

            var gdk_window = window.get_window ();
            if (gdk_window == null) return false;

            window.get_position (out normal_x, out normal_y);
            window.get_size (out normal_width, out normal_height);
            shrunk = true;

            // y = 0 asks for the very top of the screen with no work-area
            // arithmetic, because none is needed: #12 measured that a request
            // outside the work area is clamped by the window manager rather than
            // dropped, so the worst case is a card tucked under a panel rather
            // than one that does not move at all.
            //
            // No explicit raise to go with it. The toplevel is a
            // Gtk.WindowType.POPUP — override-redirect on X11 — so the window
            // manager does not restack it and set_keep_above() would be a hint to
            // a window manager that is not managing this window.
            gdk_window.move_resize (normal_x + PRACTICE_OFFSET_X, 0, CARD_WIDTH, CARD_HEIGHT);
            return true;
        }

        public bool restore () {
            // Nothing was shrunk, so there is nothing to put back — which is how
            // this satisfies "safe without a preceding shrink, and safe to call
            // twice". restore() is reached from the cancel button, from the
            // observer's aborted signal and from the step-advance timeout, and any
            // pair of those can fire for one practice session. Moving the window
            // on an unpaired restore, as this used to, meant cancelling a step the
            // user never played shifted the window for no reason.
            if (!shrunk) return true;

            var gdk_window = window.get_window ();
            if (gdk_window == null) return false;
            shrunk = false;

            gdk_window.move_resize (normal_x, normal_y, normal_width, normal_height);
            return true;
        }
    }
}
