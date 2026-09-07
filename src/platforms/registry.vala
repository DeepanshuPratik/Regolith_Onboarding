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
     * Picks the implementation of each service that suits the running session.
     *
     * Selection is per capability, not per desktop. The registry walks the list
     * below in order and, for each of the five services, takes the first platform
     * that claims the session and offers a working implementation; when none
     * does, it supplies the null implementation from the bottom of this file. So
     * a sway session ends up with sway's observer, resolver and dispatcher and
     * Wayland's placer, and a GNOME session ends up with a null observer that can
     * explain itself and a Wayland placer that works fine.
     *
     * Walking rather than matching is what keeps the list itself trivial: order
     * is the whole of the policy. Desktop platforms go above display-server
     * platforms, because a desktop that knows its own window manager should beat
     * whatever the protocol underneath it can manage generically.
     *
     * Compile-time by design (D3). Runtime .so plugins were rejected: they would
     * mean owning a public GObject ABI across Vala compiler versions for a set of
     * desktops that changes about once a year.
     *
     * A config-declared platform — a platform.conf of shell commands per
     * capability, for a desktop nobody wants to write Vala for — layers on top of
     * this without reshaping it: it is one more Platform in the list, one whose
     * claims_session() reads a file instead of an environment variable.
     */
    public class PlatformRegistry : GLib.Object {

        /**
         * Every desktop this build knows about, most specific first.
         *
         * ==> Adding a desktop is one line here. <==
         *
         * Nothing else in this file, and nothing anywhere outside the new
         * platform's own directory, needs to change: a platform that does not
         * claim the session is never asked anything, and one that claims it but
         * offers only some capabilities falls through for the rest.
         *
         * GNOME sits below sway rather than above it because it recognises a
         * session by name and distros announce GNOME alongside the window
         * manager actually running — Regolith reports
         * "Regolith-Wayland:GNOME:sway" — so GNOME claims a sway session too.
         * Below sway, it never takes a capability sway offers, and picks up only
         * what sway declines.
         */
        private static Platform[] all () {
            return {
                new SwayPlatform (),
                new GnomePlatform (),
                new KdePlatform (),
                new X11Platform (),
                new WaylandPlatform ()
            };
        }

        // Resolved once. Everything here is fixed for the life of the process, and
        // claims_session() reads the environment, which does not change under us.
        private static Platform[]? claiming = null;

        private static Platform[] claimants () {
            if (claiming == null) {
                Platform[] found = {};
                foreach (var platform in all ()) {
                    if (platform.claims_session ()) found += platform;
                }
                claiming = found;
            }
            return claiming;
        }

        private static SessionProbe? cached_probe = null;

        /**
         * Session facts, from the first claiming platform that has an opinion.
         *
         * This is what makes the window-manager id work without a central switch:
         * a platform reports its own WM by overriding one method on
         * DefaultSessionProbe, and being listed above the platforms that do not
         * know about it.
         */
        public static SessionProbe probe () {
            if (cached_probe == null) {
                foreach (var platform in claimants ()) {
                    var p = platform.probe ();
                    if (p != null) { cached_probe = p; break; }
                }
                if (cached_probe == null) cached_probe = new DefaultSessionProbe ();
            }
            return cached_probe;
        }

        /**
         * Whether practice is possible at all here.
         *
         * Answerable without building an observer, which matters: the catalogue
         * needs this before any workflow is opened, and a seat-grab observer hooks
         * key events the moment it exists.
         */
        public static bool can_practice () {
            foreach (var platform in claimants ()) {
                if (platform.can_observe ()) return true;
            }
            return false;
        }

        /** Why practice is unavailable, phrased for the user. */
        public static string no_practice_reason () {
            return new NullObserver ().unavailable_reason ();
        }

        public static ShortcutObserver observer (Gtk.Widget owner) {
            foreach (var platform in claimants ()) {
                var o = platform.observer (owner);
                if (o != null && o.available ()) return o;
            }
            return new NullObserver ();
        }

        /**
         * Used when the preferred observer fails to install or start part-way
         * through — a config.d we cannot write, an IPC subscribe that is refused.
         *
         * A seat grab regardless of session, including on Wayland where it will
         * probably never match: at that point the alternative is a PLAY button
         * that does nothing at all, and a grab at least reacts to Escape.
         */
        public static ShortcutObserver fallback_observer (Gtk.Widget owner) {
            return new SeatGrabObserver (owner);
        }

        public static BindingResolver resolver () {
            foreach (var platform in claimants ()) {
                var r = platform.resolver ();
                if (r != null && r.available ()) return r;
            }
            return new NullResolver ();
        }

        /**
         * The dispatcher that goes with this observer.
         *
         * Takes the observer rather than choosing independently because the two
         * are coupled on grab-based desktops: dispatch has to release the grab the
         * observer is holding and take it back afterwards. A platform that cannot
         * pair with the observer it is offered declines, and the walk continues.
         */
        public static ActionDispatcher dispatcher (ShortcutObserver observer) {
            foreach (var platform in claimants ()) {
                var d = platform.dispatcher (observer);
                if (d != null && d.available ()) return d;
            }

            // Pairs the fallback observer with the dispatcher that knows to
            // release its grab. Reached on a Wayland session that fell back to the
            // seat grab, where the platform that would normally dispatch has
            // declined an observer it did not make and X11Platform never claimed
            // the session at all — leaving nobody in the list to answer. This used
            // to hand back X11Dispatcher, which meant xdotool on a Wayland
            // session; the shared dispatcher asks KeySynthesizer which tool to
            // use, so the fallback now reaches for ydotool where that is the one
            // that works.
            var seat_grab = observer as SeatGrabObserver;
            if (seat_grab != null) return new SeatGrabSynthDispatcher (seat_grab);

            return new NullDispatcher ();
        }

        public static WindowPlacer placer (Gtk.Window window) {
            foreach (var platform in claimants ()) {
                var p = platform.placer (window);
                if (p != null && p.available ()) return p;
            }
            return new NullPlacer (window);
        }

        /**
         * Clear anything any claiming platform left in the user's config, whether
         * this run put it there or a run that was killed did.
         *
         * Every claimant, not just the ones whose services we ended up using: the
         * platform that wrote the mess may not be the one supplying capabilities
         * now, and leaving a config fragment behind permanently shadows keys.
         */
        /**
         * Gather what every claiming platform would need undone after a crash.
         *
         * Every claimant, for the same reason cleanup_stale_state() asks them
         * all: the platform that wrote something is not necessarily the one
         * supplying capabilities now.
         */
        public static void collect_emergency_reset (EmergencyReset into) {
            foreach (var platform in claimants ()) platform.collect_emergency_reset (into);
        }

        public static void cleanup_stale_state () {
            foreach (var platform in claimants ()) platform.cleanup_stale_state ();
        }
    }

    /**
     * What a session gets for a capability no platform offers.
     *
     * These replace the old all-or-nothing UnsupportedBackend, which could only
     * say that a desktop supported nothing. Availability differs per capability
     * per desktop — GNOME resolves and dispatches through its own APIs while
     * being unable to observe a single press — and a null per service is what
     * lets the registry hand back a working mixture instead of refusing outright.
     *
     * They are honest rather than silent. Every one answers available() == false
     * and does nothing, so a caller that forgets to check gets a no-op rather
     * than a crash, and the user gets an explanation rather than a step that
     * quietly never completes.
     */
    private class NullObserver : GLib.Object, ShortcutObserver {

        public bool available () { return false; }

        /**
         * Names the desktop and says what still works. Practice is the only thing
         * withheld — branding, slides and the workflow catalogue are unaffected,
         * and a message that did not say so would read as "this app is broken".
         */
        public string unavailable_reason () {
            var primary = PlatformRegistry.probe ().primary_desktop ();
            return "Interactive practice isn't supported on %s yet — it needs a window manager that can report keybinding events, such as sway or i3. You can still browse the workflows below to see the shortcuts.".printf (
                primary == Desktop.FALLBACK_ID ? "this desktop" : primary);
        }

        public bool install (Gee.List<Workflow> workflows) { return false; }
        public void uninstall () {}
        public bool start () { return false; }
        public void stop () {}
        public void arm (string key_id) {}
    }

    private class NullResolver : GLib.Object, BindingResolver {

        public bool available () { return false; }

        public string unavailable_reason () {
            return "No way to read this desktop's keybindings; shortcuts cannot be checked against it.";
        }

        /**
         * UNKNOWN, never UNBOUND. We did not consult the desktop, so we are not
         * entitled to say the key runs nothing — and UNKNOWN is what tells a
         * dispatcher it is free to synthesize.
         */
        public BindingLookup resolve (string key_id, out string command) {
            command = "";
            return BindingLookup.UNKNOWN;
        }
    }

    private class NullDispatcher : GLib.Object, ActionDispatcher {

        public bool available () { return false; }

        public string unavailable_reason () {
            return "Nothing here can perform a shortcut: no window-manager IPC, and no input-synthesis tool.";
        }

        public bool dispatch (string key_id, string? bound_command) { return false; }
    }

    /**
     * Placement for a session that no platform placed at all.
     *
     * Mutter used to be the case that matters here; it no longer is. A Wayland
     * session now gets layer-shell placement or, where the compositor implements
     * no layer shell, a resize-only placer that shrinks the card where it
     * stands — so every desktop this build ships for has a real placer and none
     * of them reaches this class.
     *
     * It stays because the registry's contract is that every capability has an
     * answer even when nothing in the list supplies one — a config-declared
     * platform that offers no placer, say — and because a caller that forgets to
     * check available() should get a centred window rather than a crash.
     */
    private class NullPlacer : GLib.Object, WindowPlacer {

        private Gtk.Window window;

        public NullPlacer (Gtk.Window window) { this.window = window; }

        public bool available () { return false; }

        public string unavailable_reason () {
            return "This desktop does not let an application place its own window; the shortcut card will stay where it is.";
        }

        public bool shrink_for_practice () {
            window.set_position (Gtk.WindowPosition.CENTER);
            return false;
        }

        public bool restore () {
            window.set_position (Gtk.WindowPosition.CENTER);
            return false;
        }
    }
}
