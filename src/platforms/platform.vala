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
     * Everything one desktop knows how to do, gathered behind one name.
     *
     * A platform is not required to implement all five services. That is the
     * central thing this interface exists to express and the reason every
     * factory below may return null: GNOME can resolve and dispatch while being
     * unable to observe a single keypress, and the all-or-nothing backend this
     * replaced had no way to say so. Returning null for a capability means "not
     * from me" — the registry keeps walking, and a platform further down the
     * list, or the registry's own null implementation, supplies it instead.
     *
     * The consequence worth stating plainly: the five services a session ends up
     * using need not come from a single platform. On sway the observer, resolver
     * and dispatcher come from src/platforms/sway/ while the window placer comes
     * from src/platforms/wayland/, because placement on sway is a layer-shell
     * question rather than a sway one. Composing per capability rather than
     * picking one winner is what lets a new desktop contribute only the parts it
     * genuinely does differently.
     *
     * Everything is built lazily through factory methods rather than handed over
     * as constructed objects, because half of these take grabs, spawn IPC
     * subscriptions or write to the user's config the moment they exist. The
     * registry builds only what a caller actually asks for.
     */
    public interface Platform : GLib.Object {

        /** Stable, lowercase, filesystem-safe. Matches the directory name. */
        public abstract string id ();

        /**
         * Whether this platform recognises the running session. Asked before any
         * of the factories below, so a platform that answers false is never
         * constructed and never has to guard its own methods.
         */
        public abstract bool claims_session ();

        /**
         * Session facts this platform knows better than the defaults, or null to
         * inherit DefaultSessionProbe. Overriding this is how a platform reports
         * its window manager without touching shared code.
         */
        public virtual SessionProbe? probe () { return null; }

        /**
         * Whether observer() would return something that can actually observe.
         *
         * Asked separately from building one, and the only capability that needs
         * the distinction: constructing an observer hooks key events and can take
         * a seat grab, while the workflow catalogue needs to know whether to
         * offer a PLAY button long before anything should be grabbing anything.
         */
        public virtual bool can_observe () { return false; }

        /**
         * The observer for this session. owner is the widget whose key events a
         * grab-based implementation reads; implementations that listen over IPC
         * ignore it.
         */
        public virtual ShortcutObserver? observer (Gtk.Widget owner) { return null; }

        /** Reads this desktop's binding table. Never performs anything. */
        public virtual BindingResolver? resolver () { return null; }

        /**
         * Performs a step's action. Handed the observer in use because on a
         * grab-based desktop dispatch has to drop the grab first and take it
         * back afterwards, and only the observer holding it can do that.
         */
        public virtual ActionDispatcher? dispatcher (ShortcutObserver observer) { return null; }

        /** Moves our own window out of the way. Owns the window it is given. */
        public virtual WindowPlacer? placer (Gtk.Window window) { return null; }

        /**
         * Remove anything a previous run of this platform left outside the
         * process — a config fragment, a mode still active in the WM.
         *
         * Called at quit, and callable when the app was killed last time and
         * never got to clean up. Must be safe with nothing to clean.
         */
        public virtual void cleanup_stale_state () {}
    }
}
