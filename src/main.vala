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
            // Not show_all(): the deck is still loading, and mapping now is what
            // made the app open as a white box (#33).
            window.show_when_ready ();
        }

        /**
         * The last thing to run however the app exits, and the only hook that
         * covers app.quit() — which returns to the main loop without destroying a
         * single window, so no destroy handler fires.
         *
         * Uninstalling twice costs nothing; not uninstalling at all leaves a
         * binding mode in the user's config shadowing the keys it names until
         * some later run's cleanup notices.
         */
        protected override void shutdown () {
            foreach (var window in get_windows ()) {
                var setup = window as linux_onboarding.CarouselSetup;
                if (setup != null) setup.release_practice ();
            }
            base.shutdown ();
        }
    }
    /**
     * Application entry point
     */
    public static int main (string[] args) {

        // Announce ourselves as APP_ID rather than as the binary's basename.
        //
        // GTK3 does not use the GApplication id for this: the Wayland app_id it
        // sends in xdg_toplevel.set_app_id is g_get_prgname(), which defaults to
        // argv[0]'s basename, so without this line the app_id would be
        // "linux-onboarding". GNOME stores the shortcuts-inhibit consent against
        // that string and looks it up as <app_id>.desktop; the desktop file we
        // install is named for APP_ID, and if the two do not match nothing is
        // remembered and every launch asks again. Must run before app.run().
        Environment.set_prgname (APP_ID);

        // Resolve the session's platform once; everything else reads its facts
        // from the registry rather than probing the environment itself.
        stdout.printf ("linux-onboarding: %s\n", PlatformRegistry.probe ().describe ());

        // Everything that is not an ordinary exit: a signal, a crash, or GDK
        // calling exit() because the compositor went away. See SignalGuard —
        // and note it is armed here, before the first window exists, because
        // the binding mode is installed as soon as one does.
        SignalGuard.arm ();

        foreach (var arg in args) {
            if (arg == "--check-workflows") return WorkflowCheck.run ();
            if (arg == "--reset-state")     return OnboardingState.reset ();
        }

        var app = new Application ();
        return app.run (args);
    }
}
