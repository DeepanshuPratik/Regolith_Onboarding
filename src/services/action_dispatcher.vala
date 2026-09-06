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
     * Makes the action behind a practice step actually happen.
     *
     * We hold the keyboard while a step is armed, so the compositor never gets
     * the press and the thing the user was trying to do never occurs. Something
     * has to perform it on their behalf, or practice teaches a shortcut that
     * visibly does nothing.
     *
     * There are two ways to do that, and which one an implementation uses is its
     * own business rather than the caller's: run the command the key is bound to
     * (swaymsg), or replay the keystroke through an input-synthesis tool and let
     * the desktop act on it as usual (ydotool on Wayland, xdotool on X11). A
     * desktop with neither route gets a dispatcher that says so.
     *
     * Running the resolved command is preferred where it exists — synthesis has
     * to reproduce the exact modifier combination through a second keysym
     * translation, and an unrecognised name makes ydotool fail silently, which
     * looks precisely like the step doing nothing.
     *
     * Lifecycle: none. dispatch() is self-contained and callable at any point.
     * The caller's ordering constraint is with the observer, not with us: the
     * keyboard grab must be released before dispatching and re-taken after, or
     * the synthesized keys come straight back to our own window.
     */
    public interface ActionDispatcher : GLib.Object {

        /**
         * Whether anything can be dispatched here at all.
         *
         * False means no IPC to run commands through and no synthesis tool
         * installed — the practice loop still works, but nothing visible will
         * happen when the user gets a step right, and the UI should say so
         * rather than let them think their desktop is broken.
         */
        public abstract bool available ();

        /** Why nothing can be dispatched here. Names the missing tool where it can. */
        public abstract string unavailable_reason ();

        /**
         * Perform what key_id does, and report whether anything actually
         * happened.
         *
         * bound_command is BindingResolver's answer when it resolved to BOUND,
         * and null otherwise — either because the key is genuinely bound to
         * nothing or because the desktop could not be consulted. A dispatcher
         * given null falls back to synthesizing the keystroke from key_id, which
         * is why key_id is passed even when a command is available: the two
         * routes need different inputs and the choice belongs here.
         *
         * key_id is the raw remontoire spec out of the workflow JSON,
         * e.g. "<><Shift> Enter"; translating it into keysyms is the
         * synthesizing implementation's problem, not the caller's.
         *
         * Best-effort by design. false means the action did not happen — the
         * caller should still advance the step, because the user did press the
         * right key and the failure is ours, not theirs.
         */
        public abstract bool dispatch (string key_id, string? bound_command);
    }
}
