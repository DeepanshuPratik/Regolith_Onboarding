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
     * Gets our own window out of the user's way while they practise, and puts it
     * back afterwards.
     *
     * The methods name intents, not geometry, and that is the entire point of
     * the contract. Mutter implements no layer-shell protocol and permits a
     * client no self-positioning whatsoever, so on GNOME there is no rectangle
     * we could be handed that we would be able to honour. A contract phrased as
     * move_resize(x, y, w, h) would force every caller to compute a monitor
     * workarea and an offset before finding out the answer is "not here" — work
     * thrown away, and worse, work that makes the impossible case look like a
     * bug rather than a documented limit. Asking for an outcome instead lets a
     * null placer answer honestly and lets the sway placer satisfy the same
     * request through IPC, the X11 one through move_resize, and the layer-shell
     * one through an anchor, each of which wants different numbers.
     *
     * The placer owns the window it moves; it is given one when it is built, not
     * per call. A caller has no business naming a window it does not own.
     *
     * Lifecycle, per practice session:
     *
     *     shrink_for_practice()    when the user presses PLAY
     *     restore()                on match, cancel, abort or error
     *
     * restore() must be safe to call without a preceding shrink, and safe to
     * call twice — it is reached from the cancel button, from the observer's
     * aborted signal, and from the step-advance timeout, any of which can be the
     * one that actually runs. Both calls need a realised window, so neither may
     * be made before the toplevel is mapped.
     */
    public interface WindowPlacer : GLib.Object {

        /**
         * Whether this desktop lets a client place its own window.
         *
         * True where the answer is only partial. GNOME permits no positioning
         * whatsoever but does permit a resize, and a placer that shrinks the card
         * in place is achieving the outcome that was asked for — get out of the
         * user's way — by the one means the session has. False is reserved for a
         * session where nothing at all can be done, which then keeps a window
         * exactly where the compositor put it.
         *
         * Either is a supported configuration rather than a degraded one:
         * practice itself is unaffected, and the user gets a shortcut card that
         * moves less rather than a feature that does not work.
         */
        public abstract bool available ();

        /** Why the window cannot be placed here. For the log; nothing is withheld from the user. */
        public abstract string unavailable_reason ();

        /**
         * Shrink to a small card and move clear of the working area, so the user
         * can drive their real desktop with the step still readable.
         *
         * "Clear of the working area" includes staying on top: the whole purpose
         * is to remain visible while the shortcut being practised opens a
         * terminal or switches a workspace over us. An implementation that can
         * shrink but cannot raise should still do what it can and return true —
         * false is for having done nothing at all.
         *
         * Remembering where the window was is the placer's job, not the
         * caller's. The caller has no geometry to give back.
         */
        public abstract bool shrink_for_practice ();

        /**
         * Return the window to its normal size and position, whatever that was
         * before shrink_for_practice(). A no-op returning true when the window
         * was never shrunk.
         */
        public abstract bool restore ();
    }
}
