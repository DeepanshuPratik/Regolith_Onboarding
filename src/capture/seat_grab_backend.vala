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
     * Capture with no window-manager cooperation: grab the seat and read GTK key
     * events directly.
     *
     * This is how the app worked before binding modes existed, and it remains the
     * right answer on X11, where a grab really does receive every key. On Wayland
     * it is a poor substitute — the compositor claims its own shortcuts before any
     * client sees them, so a step bound to Super+Enter will never match. It stays
     * available there only as a fallback for when WmModeBackend.start() fails.
     */
    public class SeatGrabBackend : GLib.Object, CaptureBackend {

        private Gtk.Widget owner;
        private KeybindingsHandler keys = new KeybindingsHandler ();
        private configManager cfg = new configManager ();

        private bool   listening  = false;
        private uint   armed_mask = 0;
        private uint   armed_key  = 0;
        private bool   armed_from_table = false;

        public SeatGrabBackend (Gtk.Widget owner) {
            this.owner = owner;
            owner.key_press_event.connect (on_key_press);
        }

        public bool available () { return true; }

        public string unavailable_reason () { return ""; }

        public bool start (Json.Array steps) {
            // On X11 the main window already grabbed at map time; only the Wayland
            // fallback path needs to take one here.
            if (Desktop.get_default ().is_wayland) {
                var gdkwin = owner.get_window ();
                if (gdkwin != null) {
                    var grabbed = grab_inputs (gdkwin);
                    if (grabbed != null) linux_onboarding.seat = grabbed;
                    else stderr.printf ("Failed to grab input devices.\n");
                }
            }
            return true;
        }

        public void stop () {
            listening = false;
            if (linux_onboarding.seat != null) linux_onboarding.seat.ungrab ();
        }

        public void arm (string key_id) {
            var tokens = cfg.format_spec (key_id).split (" ");
            if (tokens.length == 0) { listening = false; return; }

            armed_mask = 0;
            for (int i = 0; i < tokens.length - 1; i++)
                armed_mask |= keys.modifierMasks[tokens[i]];

            var last = tokens[tokens.length - 1];
            armed_from_table = keys.nonModifiers.get (last) != (uint) null;
            armed_key = armed_from_table ? keys.nonModifiers[last] : (uint) last[0];

            listening = true;
        }

        public void dispatch (string key_id, string fallback_command) {
            // Drop the grab so the keystroke we are about to synthesize reaches the
            // window manager rather than coming straight back to us.
            if (linux_onboarding.seat != null) linux_onboarding.seat.ungrab ();
            Posix.system (fallback_command);

            var gdkwin = owner.get_window ();
            if (linux_onboarding.seat != null && gdkwin != null) {
                linux_onboarding.seat.grab (gdkwin,
                    Gdk.SeatCapabilities.KEYBOARD | Gdk.SeatCapabilities.POINTER,
                    true, null, null, null);
            }
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
                step_matched ();
            }
            return false;
        }

        private Gdk.Seat? grab_inputs (Gdk.Window gdkwin) {
            var display = gdkwin.get_display ();
            if (display == null) { stderr.printf ("Failed to get Display\n"); return null; }
            var seat = display.get_default_seat ();
            if (seat == null) { stderr.printf ("Failed to get Seat\n"); return null; }

            int attempt = 0;
            int wait_time = 1000;
            Gdk.GrabStatus? status = null;
            do {
                status = seat.grab (gdkwin,
                    Gdk.SeatCapabilities.KEYBOARD | Gdk.SeatCapabilities.POINTER,
                    true, null, null, null);
                if (status != Gdk.GrabStatus.SUCCESS) {
                    attempt++;
                    wait_time *= 2;
                    GLib.Thread.usleep (wait_time);
                }
            } while (status != Gdk.GrabStatus.SUCCESS && attempt < 8);

            if (status != Gdk.GrabStatus.SUCCESS) {
                stderr.printf ("Failed to grab input: %d\n", status);
                return null;
            }
            return seat;
        }
    }
}
