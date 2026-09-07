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
     * Placement on a Wayland compositor that implements no layer shell: shrink
     * the window where it stands, and grow it back afterwards. Mutter is the
     * case that matters, and the only one shipped desktops reach.
     *
     * ==> There is no move here, and its absence is the design, not a gap. <==
     *
     * gtk_window_move() on Wayland emits ZERO protocol requests. GDK discards it
     * client-side and Mutter never hears about it, so it does not fail — there is
     * no error, no warning and no return value to test, and a reader adding a
     * move here would see nothing at all go wrong while nothing at all happened.
     * Measured on the wire under nested GNOME 46 / mutter 46.2 (#12).
     *
     * ==> It follows that this placer must not save and restore a position. <==
     *
     * Position cannot be READ here either: gtk_window_get_position() returns a
     * constant CSD inset and gdk_window_get_origin() returns (0, 0). A saved
     * position would be a fiction, and putting it back would be a move that goes
     * nowhere. Size is the one dimension that works — resize is honoured at
     * runtime in both directions — so the size is what is saved and the size is
     * all that is restored.
     *
     * XWayland would buy pixel-exact placement, and was rejected (#11): the
     * keyboard-shortcuts inhibitor works on Wayland-native GNOME and is the only
     * reason practice is possible there at all, while an XWayland grab cannot
     * reach compositor-level bindings. Forcing GDK_BACKEND=x11 would buy the
     * nicety at the cost of the product. Placement is a nicety; observation is
     * the product.
     */
    public class ResizeOnlyPlacer : GLib.Object, WindowPlacer {

        // The same card the layer-shell placer uses, for the same reason: small
        // enough to leave the desktop usable, large enough to read one step off.
        private const int CARD_WIDTH = 200;
        private const int CARD_HEIGHT = 150;

        private Gtk.Window window;

        // The size to grow back to, and whether there is a shrink to undo. No x
        // and no y, deliberately — see the class comment.
        private int normal_width = 0;
        private int normal_height = 0;
        private bool shrunk = false;

        public ResizeOnlyPlacer (Gtk.Window window) { this.window = window; }

        /**
         * True, even though this session permits no positioning whatsoever.
         *
         * The contract asks for an outcome — get out of the user's way — and
         * shrinking to a card achieves a real part of it by the only means the
         * session has. Answering false would make the registry walk past to the
         * null placer and the window would not shrink either, which is strictly
         * worse for the user and no more honest.
         */
        public bool available () { return true; }

        public string unavailable_reason () { return ""; }

        public bool shrink_for_practice () {
            // Idempotent, and load-bearing: a second shrink would save the card's
            // own size as the normal one and strand the window small.
            if (shrunk) return true;
            if (window.get_window () == null) return false;

            window.get_size (out normal_width, out normal_height);
            shrunk = true;

            // The size request is a MINIMUM, so it has to come down before the
            // resize or the resize is clamped straight back up to the toplevel's
            // own 800x450 request and nothing appears to happen.
            window.set_size_request (CARD_WIDTH, CARD_HEIGHT);
            window.resize (CARD_WIDTH, CARD_HEIGHT);

            // No raise to go with the shrink: Mutter honours no keep-above from a
            // client and there is no layer to move to, so the card can be covered
            // by whatever the practised shortcut opens over it. The contract
            // permits exactly this — an implementation that can shrink but cannot
            // raise should do what it can and report success.
            return true;
        }

        public bool restore () {
            // Nothing was shrunk, so there is nothing to put back — which is how
            // this satisfies "safe without a preceding shrink, and safe to call
            // twice". restore() is reached from the cancel button, from the
            // observer's aborted signal and from the step-advance timeout, and any
            // pair of those can fire for one practice session.
            if (!shrunk) return true;
            if (window.get_window () == null) return false;
            shrunk = false;

            window.set_size_request (normal_width, normal_height);
            window.resize (normal_width, normal_height);
            return true;
        }
    }
}
