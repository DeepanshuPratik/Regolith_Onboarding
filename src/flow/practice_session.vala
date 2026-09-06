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
     * The observer and its dispatcher, held for the life of the app.
     *
     * The lifetime is the whole point. ShortcutObserver's outer pair is
     * app-scoped — install() writes something into the window manager and
     * uninstall() takes it out again — so an observer built inside a practice
     * page would pay that cost on every PLAY, where a config reload is a visible
     * flicker in the middle of the thing the user is being taught. Built once at
     * startup instead, the reload happens before the window is even shown.
     *
     * That leaves three jobs that have nowhere else to live, which is why this is
     * a class and not two fields on the window:
     *
     *  - Pairing. PlatformRegistry.dispatcher() takes the observer because on a
     *    grab-based desktop dispatch has to release the grab the observer is
     *    holding. A dispatcher left pointing at a discarded observer synthesizes
     *    keystrokes straight back into our own window, so the two are only ever
     *    replaced together — see adopt().
     *
     *  - Falling back. When the preferred observer cannot install or start, the
     *    swap has to happen here rather than in the page that noticed: a page
     *    doing it would build a fresh seat grab per workflow, each one hooking
     *    the window's key events again and never letting go.
     *
     *  - Re-emitting the two signals. A page connects to this rather than to the
     *    observer, so a swap underneath it is invisible, and so the page has one
     *    stable object to disconnect from when it goes away. Connections are the
     *    page's to make and unmake, because this object outlives it and a
     *    destroyed page still wired to a live signal is a use-after-free waiting
     *    to happen.
     */
    public class PracticeSession : GLib.Object {

        // Whose key events a grab-based observer reads: the toplevel window.
        // Key events reach a GTK toplevel before they are propagated down to the
        // focused widget, so this sees every press whichever page is showing —
        // and it is the only widget here that lives as long as the observer does.
        private Gtk.Widget owner;

        // Every workflow in the catalogue. install() takes the lot at once (D5):
        // one union binding mode rather than one mode per workflow, because
        // matching is done in process by arm() and a wider mode only means seeing
        // events the observer already ignores.
        private Gee.List<Workflow> workflows;

        private ShortcutObserver observer;
        private ActionDispatcher dispatcher;

        private bool installed = false;
        private bool started   = false;
        private bool fell_back = false;

        public PracticeSession (Gtk.Widget owner, Gee.List<Workflow> workflows) {
            this.owner = owner;
            this.workflows = workflows;
            adopt (PlatformRegistry.observer (owner));
        }

        /** The armed key was pressed. */
        public signal void step_matched ();

        /** The user asked to stop practising (Escape). */
        public signal void aborted ();

        /**
         * Put the observer's half of the bargain into the world outside the
         * process. Once, at startup, before any workflow is opened.
         */
        public bool install () {
            if (installed) return true;

            // A desktop where nothing can observe gets the registry's null
            // observer, which explains itself in the catalogue. Falling back to a
            // seat grab here would hook the window's key events for a PLAY button
            // that is never shown.
            if (!PlatformRegistry.can_practice ()) return false;

            if (!observer.install (workflows)) {
                fall_back ();
                if (!observer.install (workflows)) return false;
            }

            installed = true;
            return true;
        }

        /**
         * Take it all out again. Once, at exit — and safe to call from every path
         * that reaches an exit, because whatever install() wrote is in the user's
         * config until something deletes it.
         */
        public void uninstall () {
            stop ();
            observer.uninstall ();
            installed = false;
        }

        /** Take grabs and subscribe to events, for one workflow. */
        public bool start () {
            if (started) return true;

            // install() already decided this session cannot observe at all, so
            // there is nothing to start and no fallback worth taking — a seat
            // grab on a desktop that eats its own shortcuts would only take the
            // keyboard away from the user for nothing.
            if (!installed) return false;

            if (!observer.start ()) {
                fall_back ();
                if (!observer.install (workflows) || !observer.start ()) return false;
                installed = true;
            }

            started = true;
            return true;
        }

        /** Undo start(), leaving install() alone. Safe to call more than once. */
        public void stop () {
            if (!started) return;
            observer.stop ();
            started = false;
        }

        public void arm (string key_id) { observer.arm (key_id); }

        /**
         * null command: let the dispatcher resolve the binding itself if it can.
         * Only it knows whether it would rather run the real command or replay
         * the keys.
         */
        public bool dispatch (string key_id) {
            return dispatcher.dispatch (key_id, null);
        }

        /**
         * The last resort from PlatformRegistry: a seat grab, which at least
         * reacts to Escape where the alternative is a PLAY button that does
         * nothing at all. Taken at most once per run — a second failure means
         * nothing here can observe, and building grab after grab would not
         * change that.
         */
        private void fall_back () {
            if (fell_back) return;
            fell_back = true;

            stderr.printf ("%s could not take control — falling back to a seat grab\n",
                           observer.get_type ().name ());

            // Whatever the outgoing observer put in the window manager is still
            // there; it is leaving, so it will never be asked again.
            observer.stop ();
            observer.uninstall ();
            started = false;
            installed = false;

            adopt (PlatformRegistry.fallback_observer (owner));
        }

        /**
         * Swaps the observer and the dispatcher that goes with it, together.
         * Never one without the other: see the pairing note above.
         */
        private void adopt (ShortcutObserver next) {
            if (observer != null) {
                observer.step_matched.disconnect (on_step_matched);
                observer.aborted.disconnect (on_aborted);
            }

            observer = next;
            observer.step_matched.connect (on_step_matched);
            observer.aborted.connect (on_aborted);
            dispatcher = PlatformRegistry.dispatcher (observer);
        }

        // Named methods rather than closures so adopt() can disconnect them again.
        private void on_step_matched () { step_matched (); }

        private void on_aborted () { aborted (); }
    }
}
