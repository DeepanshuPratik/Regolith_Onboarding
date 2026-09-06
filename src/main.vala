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

        // SIGTERM / SIGINT handlers.
        //
        // The app's normal exit paths (Escape, window-manager close,
        // Application.shutdown) all run release_practice() and clean up the
        // binding mode. A process killed by the user or by the system is the
        // exception: GTK never gets to run its shutdown hook, no destroy
        // handler fires, and the mode block stays in config.d, permanently
        // shadowing every key it names.
        //
        // The handlers route through the same cleanup_stale_state() the
        // shutdown path does, so the install + uninstall states are kept
        // identical: if the mode is on disk it is removed; if it is not, the
        // call is a no-op. POSIX signal handlers are very restricted about
        // what they may call, so the handler is restricted to setting a flag
        // and re-raising the signal asynchronously — which is what lets the
        // GLib main loop get back to running.
        Posix.signal (Posix.Signal.TERM, on_termination_signal);
        Posix.signal (Posix.Signal.INT,  on_termination_signal);

        foreach (var arg in args) {
            if (arg == "--check-workflows") return WorkflowCheck.run ();
            if (arg == "--reset-state")     return OnboardingState.reset ();
        }

        var app = new Application ();
        return app.run (args);
    }

    /**
     * Safety net for quitting mid-practice. The normal exit paths run
     * release_practice() through CarouselSetup.quit() and Application.shutdown;
     * a SIGTERM/SIGINT skips both, so the mode block can be left in config.d.
     * Routing through the registry's static cleanup covers the whole platform
     * list (not just sway): a future Wayland observer that writes to disk will
     * get cleaned up here without this file having to be edited again.
     */
    private static void on_termination_signal (int sig) {
        PlatformRegistry.cleanup_stale_state ();
        // Re-raise with the default handler so the shell reports the
        // signal-induced exit, not a clean zero. Passing null to
        // Posix.signal() restores the C default disposition (SIG_DFL).
        Posix.signal (sig, (Posix.sighandler_t) null);
        Posix.raise (sig);
    }
}
