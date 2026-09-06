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
     * Whether this compositor implements zwlr_layer_shell_v1.
     *
     * Every gtk-layer-shell call in this app is gated on this, and the gate is
     * not a politeness — on a compositor without the protocol those calls are
     * fatal. Mutter implements no layer shell at all, so this is the difference
     * between the app running on GNOME and the app dying on startup there.
     *
     * ==> The failure is staged, which is the whole reason this file exists. <==
     *
     * Measured on nested GNOME 46 / mutter 46.2: init_for_window(), set_layer()
     * and set_keyboard_mode() each log a CRITICAL
     * (`layer_surface_new: assertion 'gtk_wayland_get_layer_shell_global ()' failed`)
     * and then RETURN NORMALLY. Nothing throws, nothing reports failure, and
     * construction appears to have worked. The process only dies later — SIGABRT,
     * exit 134, core dumped — inside libwayland-client's dispatch during the
     * roundtrip in gtk_widget_map(), i.e. from show_all(), which is nowhere near
     * the calls that caused it.
     *
     * So a future reader who checks whether the layer-shell calls "succeed" will
     * see them return and conclude this gate is redundant. It is not. Removing it
     * does not restore a working call — it relocates the crash to show_all(),
     * where nothing points back here.
     *
     * Cached because gtk_layer_is_supported() costs a Wayland roundtrip and the
     * answer cannot change under us: a compositor does not gain or lose a global
     * while a client is connected to it.
     */
    public class LayerShellSupport : GLib.Object {

        private static bool resolved = false;
        private static bool supported = false;

        /**
         * Not safe to call before Gtk.init(): the answer is read off the open GDK
         * display, and asking too early would cache a false negative for the life
         * of the process. Every caller sits behind window construction or a user
         * action, so this holds — and --check-workflows, which never opens a
         * display, must never reach here.
         */
        public static bool available () {
            if (!resolved) {
                // Short-circuit rather than ask when the session is not Wayland at
                // all: layer shell is a Wayland protocol, and an X11 session has
                // already answered this question without paying for a roundtrip.
                supported = Desktop.get_default ().is_wayland
                            && GtkLayerShell.is_supported ();
                resolved = true;
            }
            return supported;
        }
    }
}
