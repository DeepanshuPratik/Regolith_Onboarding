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
     * GNOME, on Mutter.
     *
     * The case the five-service split was designed to be able to express: this
     * platform resolves and dispatches, and observes via a keyboard-only seat
     * grab. The grab is the only thing that gets Mutter to honour
     * zwp_keyboard_shortcuts_inhibit_v1, which is the whole point — without
     * inhibition the compositor eats every shortcut we want to teach.
     *
     * Two of the five are still open:
     *   - placer() — Mutter implements no layer-shell and permits a client no
     *     self-positioning, and gtk_layer_init_for_window() is outright fatal
     *     there. Leaving it null means the registry's NullPlacer centres the
     *     window and says why, which is the honest behaviour until that ticket
     *     decides on the XWayland route.
     */
    public class GnomePlatform : GLib.Object, Platform {

        public string id () { return "gnome"; }

        /**
         * Recognised from the desktop candidates rather than from a socket in the
         * environment, because GNOME publishes no equivalent of SWAYSOCK to find.
         *
         * The whole candidate list, not just the most specific entry: distros
         * announce themselves ahead of the desktop they are built on —
         * "ubuntu:GNOME", "Regolith-Wayland:GNOME:sway" — so anything that
         * insisted on being first would fail to recognise GNOME on the systems
         * most likely to be running it.
         *
         * The consequence is that this claims some sessions GNOME is not actually
         * driving, Regolith's being the one that ships here. That is what the
         * registry's ordering is for: platforms naming a window manager they can
         * really drive are listed above this one and take the capabilities they
         * offer first.
         */
        public bool claims_session () {
            foreach (var candidate in Desktop.get_default ().candidates) {
                if (candidate == "gnome") return true;
            }
            return false;
        }

        /**
         * Deliberately no probe of its own. A platform overrides that to report a
         * window manager it can hold a conversation with, and there is no
         * conversation to hold with Mutter — no IPC socket, no queryable config.
         * Reporting "gnome" as a window manager would read as a capability this
         * does not have.
         */

        public BindingResolver? resolver () { return new GnomeResolver (); }

        /**
         * A seat grab, and the only kind that works: the keyboard-only grab
         * SeatGrabObserver takes is what triggers zwp_keyboard_shortcuts_inhibit_v1
         * on Mutter, which the compositor honours with no Super-key carve-out
         * (spike #11 measured this on the wire). Asking for `| POINTER` instead
         * silently drops the inhibitor request, so practice on GNOME would
         * visibly do nothing — a louder failure but the same outcome.
         *
         * The grab's recovery story is the user: Mutter refuses to give focus
         * back via xdg_activation_v1, and the re-grab after focus loss is inert,
         * so SeatGrabObserver exposes a click-to-continue prompt as the primary
         * path rather than a fallback. Everything here is in
         * src/platforms/x11/observer.vala because the X11 dispatcher needs the
         * exact same observer to release and retake the grab around dispatch.
         */
        public ShortcutObserver? observer (Gtk.Widget owner) {
            return new SeatGrabObserver (owner);
        }

        public bool can_observe () { return true; }

        /**
         * Only pairs with the observer that holds a seat grab, for the same
         * reason X11Platform does: the dispatcher has to release that grab around
         * the replay and take it back, and an observer it was not given cannot be
         * asked to do either.
         *
         * That is the seat-grab observer today because GNOME has none of its own
         * until #14, and it is the right pairing rather than a placeholder — the
         * grab whose shortcuts-inhibitor swallows the injected keys is precisely
         * the one SeatGrabObserver takes.
         */
        public ActionDispatcher? dispatcher (ShortcutObserver observer) {
            var seat_grab = observer as SeatGrabObserver;
            return seat_grab == null ? null : new SeatGrabSynthDispatcher (seat_grab);
        }

        /**
         * Nothing to clean. Unlike a binding mode written into config.d, reading
         * GSettings and replaying a keystroke leave nothing outside the process
         * for a later run to find.
         */
    }
}
