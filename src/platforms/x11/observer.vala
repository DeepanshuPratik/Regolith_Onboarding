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
     * Observation by grabbing the seat and reading GTK key events.
     *
     * Correct on X11 outright: a grab really does receive every key. On Wayland
     * it is the only option short of a desktop-specific mechanism, and it is the
     * one spike #11 measured works — a keyboard-only grab is what makes GTK
     * request zwp_keyboard_shortcuts_inhibit_v1, which the compositor honours
     * with no carve-out for Super. Asking for `KEYBOARD | POINTER` instead emits
     * no protocol traffic at all, so the inhibitor is never requested and
     * nothing here would ever match on Mutter or KWin.
     *
     * The Wayland half has its own recovery story. GrabStatus, has_toplevel_focus,
     * is_active and focus-in-event all lie after a grab — a denied grab returns
     * SUCCESS, GDK synthesises a FOCUS-IN while another client demonstrably
     * holds focus, and the only ground truth is a key event actually arriving
     * plus a timeout. The app also cannot take focus back on its own: Mutter
     * refuses xdg_activation_v1, and the re-grab after focus loss is inert
     * regardless. Recovery on GNOME is therefore user-driven: a click-to-continue
     * prompt is the primary path, not a fallback. The inhibitor goes live again
     * on its own once focus genuinely returns, with no new grab and no second
     * consent dialog.
     *
     * Installs and uninstalls are no-ops on this class. Nothing the grab leaves
     * outside the process has to be reaped; the only state is in the GDK seat,
     * which lives and dies with start() and stop().
     */
    public class SeatGrabObserver : GLib.Object, ShortcutObserver {

        private Gtk.Widget owner;
        private KeyTables keys = new KeyTables ();
        private KeySpec spec = new KeySpec ();

        private bool   listening  = false;
        private uint   armed_mask = 0;
        private uint   armed_key  = 0;
        private bool   armed_from_table = false;

        // The grab held right now, taken by start() and dropped by stop() in
        // every session (#29). Null between workflows.
        private Gdk.Seat? grab_seat = null;

        // Re-grab state on Wayland. focus-in tells us focus came back; the
        // key-arrival timeout is the ground-truth signal that the grab is
        // actually receiving events. Two minutes is generous — a step the user
        // is no longer trying to perform is not worth blocking the rest of the
        // app for.
        private bool            regrab_pending = false;
        private uint            regrab_timeout_id = 0;
        private const uint      REGRAB_TIMEOUT_MS = 120 * 1000;

        public SeatGrabObserver (Gtk.Widget owner) {
            this.owner = owner;
            owner.key_press_event.connect (on_key_press);
            owner.focus_in_event.connect (on_focus_in);
        }

        public bool available () { return grab_seat != null || true; }

        public string unavailable_reason () { return ""; }

        /**
         * No-op. The seat grab lives in start()/stop() and is not process state
         * that outlives us, so a run that never gets to stop() leaves nothing for
         * a later run to clean up — unlike a sway binding mode, which has to.
         */
        public bool install (Gee.List<Workflow> workflows) { return true; }

        public void uninstall () {}

        /**
         * Take the grab — one keyboard-only grab, taken here, on every desktop.
         *
         * This used to have two paths: on X11 it adopted a seat the toplevel had
         * already grabbed at map time, and only on Wayland did it grab for
         * itself. The toplevel's grab is gone (#29), so there is one path and one
         * owner. The X11 side loses nothing by it — an X grab taken at PLAY
         * receives every key just as one taken at startup did — and the app stops
         * holding the user's keyboard while they read the slides.
         *
         * A grab whose request succeeds is still not a grab that works: on
         * Wayland the request returns SUCCESS when it is inert, so the only
         * ground truth is a key arriving. That is what the re-grab timeout is
         * for, and it is armed here whichever session we are in.
         */
        public bool start () {
            var gdkwin = owner.get_window ();
            if (gdkwin == null) return false;

            var grabbed = grab_keyboard_only (gdkwin);
            if (grabbed == null) {
                stderr.printf ("Failed to acquire keyboard for shortcut observation.\n");
                return false;
            }
            grab_seat = grabbed;
            arm_regrab_timeout ();
            return true;
        }

        public void stop () {
            cancel_regrab_timeout ();
            regrab_pending = false;
            listening = false;
            // Ours in every session now, so it is ours to drop.
            if (grab_seat != null) grab_seat.ungrab ();
            grab_seat = null;
        }

        public void arm (string key_id) {
            var tokens = spec.format_spec (key_id).split (" ");
            if (tokens.length == 0) { listening = false; return; }

            armed_mask = 0;
            for (int i = 0; i < tokens.length - 1; i++)
                armed_mask |= keys.modifierMasks[tokens[i]];

            var last = tokens[tokens.length - 1];
            armed_from_table = keys.nonModifiers.get (last) != (uint) null;
            armed_key = armed_from_table ? keys.nonModifiers[last] : (uint) last[0];

            listening = true;

            // A step the user is expected to perform is also a step whose grab
            // needs to be live. If focus has been lost, prompt the user to come
            // back — click-to-continue is the primary recovery path on GNOME.
            if (regrab_pending) prompt_user_to_return ();
        }

        /**
         * Drop the grab so a keystroke the dispatcher is about to synthesize
         * reaches the window manager rather than coming straight back to us.
         * Called by the dispatcher; nothing else should be holding the seat.
         */
        public void release_grab () {
            if (grab_seat != null) grab_seat.ungrab ();
        }

        /**
         * Take the grab back once the dispatched action has been sent.
         *
         * KEYBOARD only — see class comment. The X11 dispatcher also calls this,
         * and on X11 asking for POINTER alongside was already unnecessary, so
         * dropping it is harmless there and load-bearing on Wayland.
         */
        public void retake_grab () {
            var gdkwin = owner.get_window ();
            if (grab_seat == null || gdkwin == null) return;
            grab_seat.grab (gdkwin,
                Gdk.SeatCapabilities.KEYBOARD,
                true, null, null, null);
        }

        private bool on_key_press (Gdk.EventKey key) {
            if (!listening) return false;

            if (key.keyval == KEY_CODE_ESCAPE) {
                listening = false;
                aborted ();
                return false;
            }

            if (keys.match (key, armed_mask, armed_key, armed_from_table)) {
                listening = false;
                cancel_regrab_timeout ();
                step_matched ();
            }
            return false;
        }

        /**
         * focus-in-event on Wayland is the only signal that focus has genuinely
         * returned; the GTK-level focus properties lie (see class comment). We
         * re-grab here, but the grab itself may still be inert — a key arriving
         * through it is the only thing that proves it.
         */
        private bool on_focus_in (Gdk.EventFocus ev) {
            if (!regrab_pending) return false;
            regrab_pending = false;
            cancel_regrab_timeout ();
            arm_regrab_timeout ();  // arm again with the *new* deadline
            retake_grab ();
            return false;
        }

        private void arm_regrab_timeout () {
            cancel_regrab_timeout ();
            regrab_timeout_id = GLib.Timeout.add (REGRAB_TIMEOUT_MS, () => {
                regrab_timeout_id = 0;
                // No key arrived through the grab; assume focus has been lost
                // and prompt the user. The user is the recovery path on GNOME.
                if (listening) prompt_user_to_return ();
                return Source.REMOVE;
            });
        }

        private void cancel_regrab_timeout () {
            if (regrab_timeout_id != 0) {
                GLib.Source.remove (regrab_timeout_id);
                regrab_timeout_id = 0;
            }
        }

        /**
         * A click-to-continue prompt, raised when the user has to bring focus
         * back themselves. On Mutter the re-grab is inert until they do, and
         * the app cannot take focus on its own — see the class comment. The
         * prompt is what the practice page surfaces; we only flag the state.
         */
        private void prompt_user_to_return () {
            regrab_pending = true;
            needs_user_focus ();
        }

        /**
         * Emitted when the observer would like the practice UI to draw a
         * "click here to continue" prompt. No payload: a step's prompt is the
         * practice page's choice, and the only fact the observer owns is that
         * the grab is no longer doing its job.
         */
        public signal void needs_user_focus ();

        /**
         * Called by the practice page when the user clicks the prompt.
         * The user clicking the window is what brings focus back; the
         * focus-in handler then performs the re-grab and the existing inhibitor
         * wakes up on its own.
         */
        public void user_returned () {
            regrab_pending = false;
            cancel_regrab_timeout ();
            arm_regrab_timeout ();
        }

        /**
         * Take a keyboard-only seat grab.
         *
         * Retries with exponential backoff because the previous focus owner
         * releasing its grab is not instantaneous; observed on Mutter to take
         * up to a second after a window manager close.
         */
        private Gdk.Seat? grab_keyboard_only (Gdk.Window gdkwin) {
            var display = gdkwin.get_display ();
            if (display == null) { stderr.printf ("Failed to get Display\n"); return null; }
            var seat = display.get_default_seat ();
            if (seat == null) { stderr.printf ("Failed to get Seat\n"); return null; }

            int attempt = 0;
            int wait_time = 1000;
            Gdk.GrabStatus? status = null;
            do {
                status = seat.grab (gdkwin,
                    Gdk.SeatCapabilities.KEYBOARD,   // NOT `| POINTER`; see class comment
                    true, null, null, null);
                if (status != Gdk.GrabStatus.SUCCESS) {
                    attempt++;
                    wait_time *= 2;
                    GLib.Thread.usleep (wait_time);
                }
            } while (status != Gdk.GrabStatus.SUCCESS && attempt < 8);

            if (status != Gdk.GrabStatus.SUCCESS) {
                stderr.printf ("Failed to grab keyboard: %d\n", status);
                return null;
            }
            return seat;
        }
    }
}
