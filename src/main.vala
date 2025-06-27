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
using GtkLayerShell;

// Globals
bool IS_SESSION_WAYLAND;
string WM_NAME;

namespace regolith_onboarding {

    public class Application : Gtk.Application {
        public Application () {
            Object (application_id: APP_ID,
                flags: ApplicationFlags.FLAGS_NONE);
        }

        protected override void activate () {
            var window = new regolith_onboarding.CarouselSetup (this);
            window.show_all ();
        }
    }
    /**
     * Application entry point
     */
    public static int main (string[] args) {

        // Get session type (wayland or x11) and set the flag
        string session_type = Environment.get_variable ("XDG_SESSION_TYPE");
        string gdk_backend = Environment.get_variable ("GDK_BACKEND");
        IS_SESSION_WAYLAND = session_type == "wayland" && gdk_backend != "x11";

        // Set window manager
        if (Environment.get_variable ("SWAYSOCK") != null) {
            WM_NAME = "sway";
        } else if (Environment.get_variable ("I3SOCK") != null) {
            WM_NAME = "i3";
        } else {
            WM_NAME = "Unknown";
        }
        
        var app = new Application ();
        return app.run (args);
    }
}