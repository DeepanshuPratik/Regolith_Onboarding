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
     * to a card in the top-left corner for practice, and put it back in the
     * middle of the monitor's working area afterwards.
     *
     * Remembering the original horizontal position is this class's job and not
     * the caller's — the contract hands out intents, not geometry, so there is no
     * rectangle for a caller to hand back. It is read the first time either
     * method runs, including when restore() is reached first through the cancel
     * button without any preceding shrink.
     */
    public class X11Placer : GLib.Object, WindowPlacer {

        // The shrunk card sits this far right of where the window started, which
        // keeps it clear of a terminal opening at the left edge.
        private const int PRACTICE_OFFSET_X = 300;

        private Gtk.Window window;
        private int origin_x = 0;
        private bool origin_known = false;

        public X11Placer (Gtk.Window window) {
            this.window = window;
        }

        public bool available () { return true; }

        public string unavailable_reason () { return ""; }

        public bool shrink_for_practice () {
            var gdk_window = window.get_window ();
            if (gdk_window == null) return false;
            remember_origin ();
            gdk_window.move_resize (origin_x + PRACTICE_OFFSET_X, 0, 200, 150);
            return true;
        }

        public bool restore () {
            var gdk_window = window.get_window ();
            if (gdk_window == null) return false;
            remember_origin ();

            var monitor = Gdk.Display.get_default ().get_monitor_at_window (gdk_window);
            var workarea = monitor.get_workarea ();
            gdk_window.move_resize (origin_x, workarea.height / 2 - 255, 800, 450);
            return true;
        }

        private void remember_origin () {
            if (origin_known) return;
            int x, y;
            window.get_position (out x, out y);
            origin_x = x;
            origin_known = true;
        }
    }
}
