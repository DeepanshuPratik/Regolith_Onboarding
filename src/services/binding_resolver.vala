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
     * The answer to "what is this key bound to here?".
     *
     * Three outcomes, not two, because "the desktop has no binding for this
     * key" and "I could not find out" are different facts that call for
     * different behaviour, and collapsing them into a null string loses the
     * distinction exactly where it matters. On GNOME most default bindings ship
     * empty, so UNBOUND is an ordinary answer about a working desktop and must
     * never be reported to the user as a failure.
     */
    public enum BindingLookup {
        /** The key runs a command, returned through the out parameter. */
        BOUND,

        /**
         * The desktop was consulted and this key runs nothing: an empty GSettings
         * array, or a sway `bindsym ... nop`. A normal answer, not an error.
         */
        UNBOUND,

        /**
         * The desktop could not be consulted — no IPC socket, no schema
         * installed, a config we cannot parse. We know nothing about this key,
         * which is not the same as knowing it does nothing.
         */
        UNKNOWN
    }

    /**
     * Answers what a key is really bound to on this desktop, without performing
     * anything.
     *
     * Resolution used to be fused into dispatch — one method that hunted through
     * the sway config and ran the first matching bindsym it found, so the answer
     * was never visible and could not be reused. Splitting it out buys three
     * things: --check-workflows can validate an author's key_ids offline against
     * the real desktop, the UI can show the user what the key will do before
     * they press it, and dispatch stops having to re-derive what resolution
     * already knew.
     *
     * Resolvers report; they never act. A resolver that runs a command is a bug,
     * because --check-workflows calls this on every step of every shipped
     * workflow.
     *
     * Lifecycle: none, and no ordering constraints. resolve() is callable at any
     * point, including before any window exists and with no workflow in
     * progress. Implementations may cache the desktop's binding table on first
     * use — it does not change underneath us within a run, and re-reading a
     * whole sway config per step was measurable.
     */
    public interface BindingResolver : GLib.Object {

        /**
         * Whether this resolver can consult the desktop at all.
         *
         * Answered separately from observation on purpose: GNOME exposes its
         * bindings through org.gnome.desktop.wm.keybindings and resolves
         * perfectly well while being unable to observe a single press.
         */
        public abstract bool available ();

        /** Why resolution is impossible here. For the log and --check-workflows. */
        public abstract string unavailable_reason ();

        /**
         * What key_id is bound to, as the raw remontoire spec out of the workflow
         * JSON, e.g. "<><Shift> Enter".
         *
         * command is set only when the result is BOUND, and is in whatever form
         * the matching dispatcher expects — a sway command for the sway pair, a
         * GSettings action name elsewhere. It is not a shell command and must
         * not be run by the caller; hand it to ActionDispatcher.
         *
         * A resolver that is unavailable() answers UNKNOWN rather than refusing,
         * so a caller that does not care about the distinction can call this
         * unconditionally.
         */
        public abstract BindingLookup resolve (string key_id, out string command);
    }
}
