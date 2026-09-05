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
     * Stands in for desktops where keypress capture is not implemented yet —
     * GNOME and KDE on Wayland, chiefly. Those compositors consume their own
     * shortcuts before any client sees them and expose no binding-event stream we
     * can subscribe to, so a grab would silently never match.
     *
     * Reporting that honestly is better than shipping practice steps that quietly
     * do nothing: branding, slides and the workflow catalogue all still work, and
     * only the interactive part is withheld.
     *
     * A real GNOME implementation has a clear starting point whenever someone
     * wants it — org.gnome.desktop.wm.keybindings and
     * org.gnome.settings-daemon.plugins.media-keys expose the bindings via
     * GSettings; the missing half is a way to observe the presses.
     */
    public class UnsupportedBackend : GLib.Object, CaptureBackend {

        public bool available () { return false; }

        public string unavailable_reason () {
            var desktop = Desktop.get_default ();
            return "Interactive practice isn't supported on %s yet — it needs a window manager that can report keybinding events, such as sway or i3. You can still browse the workflows below to see the shortcuts.".printf (
                desktop.primary == Desktop.FALLBACK_ID ? "this desktop" : desktop.primary);
        }

        public bool start (Json.Array steps) { return false; }
        public void stop () {}
        public void arm (string key_id) {}
        public void dispatch (string key_id, string fallback_command) {}
    }
}
