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
     * Any X11 session, including XWayland — GDK_BACKEND=x11 inside a Wayland
     * compositor puts us here, and correctly so, because it is the X11 code paths
     * that then work.
     *
     * A display-server layer like WaylandPlatform, and listed below the desktop
     * platforms so that a tiling WM running on X11 still gets its own observer
     * and only falls back to the seat grab for what it does not provide.
     *
     * Names no window manager. Everything here works the same whichever one is
     * running, and a WM worth naming will have a platform of its own listed
     * above this one.
     */
    public class X11Platform : GLib.Object, Platform {

        public string id () { return "x11"; }

        public bool claims_session () { return !Desktop.get_default ().is_wayland; }

        public bool can_observe () { return true; }

        public ShortcutObserver? observer (Gtk.Widget owner) {
            return new SeatGrabObserver (owner);
        }

        /**
         * Only pairs with an observer of our own. The dispatcher has to release
         * and retake that observer's grab around the synthesized keystroke, so
         * handing it somebody else's observer would leave the grab held and the
         * keys would come straight back to our own window.
         */
        public ActionDispatcher? dispatcher (ShortcutObserver observer) {
            var seat_grab = observer as SeatGrabObserver;
            return seat_grab == null ? null : new X11Dispatcher (seat_grab);
        }

        public WindowPlacer? placer (Gtk.Window window) {
            return new X11Placer (window);
        }
    }
}
