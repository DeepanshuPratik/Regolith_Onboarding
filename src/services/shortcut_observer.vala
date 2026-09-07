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
     * Noticing that the key a practice step is waiting on was actually pressed.
     *
     * This is the capability desktops differ on most, and the only one some of
     * them cannot offer at all. A tiling WM lets us install a binding mode and
     * subscribe to its IPC, which is precise and needs no input grab. On X11 a
     * seat grab genuinely receives every key. A Wayland compositor with no IPC
     * we understand consumes its own shortcuts before any client sees them, and
     * there is no portable way to observe a shortcut the compositor owns — the
     * GlobalShortcuts portal registers new bindings, it does not report existing
     * ones. Such a desktop answers available() == false and says so, which is
     * the whole reason observation is a service of its own: GNOME can resolve
     * and dispatch perfectly well while being unable to observe, and the old
     * all-or-nothing backend had no way to say that.
     *
     * Observation and dispatch are deliberately separate: an observer only ever
     * reports, it never performs. Making the action happen is ActionDispatcher's
     * job, which is what lets the same observer serve a future demo mode where
     * the app presses the key itself.
     *
     * Lifecycle. Note the outer pair is app-scoped, not per workflow: an
     * observer that installs something in the window manager pays that cost
     * once, at startup, where a config reload is invisible, rather than in the
     * middle of practice where it is a visible flicker.
     *
     *     install(workflows)  once, at startup
     *       start()           once per workflow
     *         arm(key_id)     once per step
     *       stop()            once, on finish or cancel
     *     uninstall()         once, at exit
     *
     * Within a step the caller runs the practice loop from the map: hold the
     * grab, release it only long enough for the dispatcher to act, then take it
     * again. An observer must therefore tolerate arm() being called again for a
     * key it has already matched, and stop() being called from a signal handler
     * of its own signals.
     *
     * install() and uninstall() must also survive the process being killed
     * between them — anything written to the user's config is the observer's to
     * clean up on the next run if it was not cleaned up on this one.
     */
    public interface ShortcutObserver : GLib.Object {

        /** Whether this observer can actually notice presses in this session. */
        public abstract bool available ();

        /**
         * Shown to the user when available() is false, so it has to name the
         * desktop and say what still works. Practice is the only thing withheld
         * here — branding, slides and the workflow catalogue are unaffected.
         */
        public abstract string unavailable_reason ();

        /**
         * Put anything this observer needs into the world outside the process,
         * for every workflow at once: a WM binding mode, a config fragment.
         * Called once at startup, before any workflow is opened.
         *
         * One mode covers every key from every workflow rather than one mode per
         * workflow. Matching is done in-process by arm(), so a wider mode only
         * means seeing events we ignore — which the observer already does — while
         * a mode per workflow would multiply the config text and the escaping
         * burden for no behavioural gain.
         *
         * Whatever this writes is built from workflow JSON, which can arrive from
         * a marketplace repository. An implementation that composes config text
         * from key_id strings MUST reject anything that could terminate the block
         * it is writing; a key_id is untrusted input, not a format string.
         *
         * Returns false if nothing could be installed, in which case the caller
         * should try another observer before any workflow starts.
         */
        public abstract bool install (Gee.List<Workflow> workflows);

        /** Remove everything install() put outside the process. Safe to call twice. */
        public abstract void uninstall ();

        /**
         * Begin a workflow: take grabs, subscribe to events. Returns false if
         * control could not be taken, in which case the caller should try
         * another observer.
         *
         * Deliberately takes no argument. Everything an observer needs to know
         * about the workflows was given to install(); a step's key arrives
         * through arm(). An observer that needs to distinguish one workflow from
         * another is doing something install() should have done once.
         */
        public abstract bool start ();

        /** Undo everything start() did. Must be safe to call more than once. */
        public abstract void stop ();

        /**
         * Begin listening for one step's key. key_id is the raw remontoire spec
         * straight out of the workflow JSON, e.g. "<><Shift> Enter" — each
         * observer translates it into whatever form it matches against.
         *
         * Only one key is armed at a time; arming replaces whatever was armed
         * before rather than adding to it.
         */
        public abstract void arm (string key_id);

        /** The armed key was pressed. */
        public signal void step_matched ();

        /** The user asked to stop practising (Escape). */
        public signal void aborted ();
    }
}
