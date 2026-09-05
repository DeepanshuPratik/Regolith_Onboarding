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

namespace linux_onboarding {

    public class Application : Gtk.Application {
        public Application () {
            Object (application_id: APP_ID,
                flags: ApplicationFlags.FLAGS_NONE);
        }

        protected override void activate () {
            var window = new linux_onboarding.CarouselSetup (this);
            window.show_all ();
        }
    }
    /**
     * Application entry point
     */
    public static int main (string[] args) {

        // Resolve session facts once; everything else reads them from here.
        stdout.printf ("linux-onboarding: %s\n", Desktop.get_default ().describe ());

        foreach (var arg in args) {
            if (arg == "--check-workflows") return WorkflowCheck.run ();
        }

        var app = new Application ();
        return app.run (args);
    }
}
