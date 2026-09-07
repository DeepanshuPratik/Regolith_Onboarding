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
     * KDE Plasma: observation by keyboard-only seat grab, resolution from
     * kglobalshortcutsrc, dispatch by replay.
     *
     * This directory exists because the support tables in README and
     * DISTRO-GUIDE claimed KDE worked when no code here had ever mentioned it
     * (#28). A Plasma Wayland session used to be claimed only by
     * WaylandPlatform, which offers a placer and nothing else, so practice was
     * unavailable and the app said so — while the documentation said the
     * opposite.
     *
     * Nothing here is new machinery. KWin honours
     * zwp_keyboard_shortcuts_inhibit_v1 (since Plasma 5.20) exactly as Mutter
     * does, so the shared SeatGrabObserver is the right observer and the shared
     * SeatGrabSynthDispatcher is the right dispatcher; the only thing genuinely
     * KDE's own is where the binding table lives, which is KdeResolver. That is
     * what "one directory per desktop" is supposed to feel like.
     *
     * No placer. KWin implements zwlr_layer_shell_v1, so WaylandPlatform's
     * placer is already the right answer where it is supported and its
     * resize-only fallback is the right answer where it is not — a KDE-specific
     * placer would be the same code with a narrower claim.
     *
     * **Untested on real KWin.** The observer, dispatcher and inhibitor
     * behaviour are inherited from what spike #11 measured on Mutter plus what
     * it read of KWin's implementation; the resolver's parsing is covered by
     * tests/test_kde_bindings. What no one has done is run this on Plasma. The
     * support tables now say exactly that, which is the part that was wrong
     * before.
     */
    public class KdePlatform : GLib.Object, Platform {

        public string id () { return "kde"; }

        /**
         * Plasma sets XDG_CURRENT_DESKTOP=KDE, and has done since long before
         * Wayland; "plasma" is accepted too because some spins write it.
         */
        public bool claims_session () {
            foreach (var candidate in Desktop.get_default ().candidates) {
                if (candidate == "kde" || candidate == "plasma") return true;
            }
            return false;
        }

        public bool can_observe () { return true; }

        public ShortcutObserver? observer (Gtk.Widget owner) {
            return new SeatGrabObserver (owner);
        }

        public BindingResolver? resolver () { return new KdeResolver (); }

        /**
         * Only ever paired with the grab, because dispatch has to drop it: keys
         * injected at the evdev level while we hold a keyboard grab come back to
         * us instead of reaching KWin, and the shortcut visibly does nothing.
         */
        public ActionDispatcher? dispatcher (ShortcutObserver observer) {
            var seat_grab = observer as SeatGrabObserver;
            return seat_grab == null ? null : new SeatGrabSynthDispatcher (seat_grab);
        }
    }
}
