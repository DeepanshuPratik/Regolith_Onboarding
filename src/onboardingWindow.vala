// filename: src/onboardingWindow.vala

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
using Gee;

namespace linux_onboarding {

    // Keyvals the capture code compares against.
    public const int KEY_CODE_ESCAPE = 65307;
    public const int KEY_CODE_TAB    = 65289;
    public const int KEY_CODE_UP     = 65362;
    public const int KEY_CODE_DOWN   = 65364;
    public const int KEY_CODE_LEFT   = 65361;
    public const int KEY_CODE_RIGHT  = 65363;
    public const int KEY_CODE_ENTER  = 65293;

    // Held by SeatGrabBackend across its grab/ungrab cycles.
    protected Gdk.Seat seat;

    public class CarouselSetup : Window {

        // Navigation stays off so a stray scroll cannot jump pages mid-practice.
        private const bool ALLOW_CAROUSEL_GESTURES = false;

        private Gtk.Box container;
        private Hdy.Carousel carousel;
        private WorkFlowPage workflowPage;
        private Gee.List<Workflow> workflows;

        public CarouselSetup (Gtk.Application app) {
            Object(application: app, type: Gtk.WindowType.POPUP);
            window_position = WindowPosition.CENTER;

            if (Desktop.get_default ().is_wayland) {
                set_size_request (800,450);
            } else {
                set_default_size (800,450);
            }

            var css_provider = new Gtk.CssProvider();
            try {
                css_provider.load_from_resource(APP_PATH + "/css/app.css");
                Gtk.StyleContext.add_provider_for_screen(this.get_screen(), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
            } catch (Error e) {
                error ("Cannot load CSS stylesheet: %s", e.message);
            }
            this.get_style_context().add_class("carousel");

            container = new Box(Gtk.Orientation.VERTICAL, 30);
            container.get_style_context().add_class("main-container");
            this.add(container);

            carousel = new Hdy.Carousel();
            container.add(carousel);

            var carousel_indicator = new Hdy.CarouselIndicatorDots();
            carousel_indicator.set_carousel(carousel);
            container.add(carousel_indicator);

            workflows = new WorkflowLocator ().load ();

            var worflowsListPage = new WorkFlows(workflows, (workflow)=>{
              create_practice_page(workflow);
              this.remove(container);
              this.add(workflowPage);
              this.show_all();
            });

            var introPage = new IntroPage(()=>{
                carousel.scroll_to_full(worflowsListPage, 800);
            });

            carousel.insert(introPage, 0);
            carousel.insert(worflowsListPage, 1);
            carousel.set_spacing(100);

            carousel.set_allow_scroll_wheel(ALLOW_CAROUSEL_GESTURES);
            carousel.set_allow_mouse_drag(ALLOW_CAROUSEL_GESTURES);
            carousel.set_allow_long_swipes(ALLOW_CAROUSEL_GESTURES);

            key_press_event.connect ((key) => {
                if (key.keyval == KEY_CODE_ESCAPE) {
                    clean_config();
                    quit();
                }
                return false;
            });

            if (Desktop.get_default ().is_wayland) {
                GtkLayerShell.init_for_window (this);
                GtkLayerShell.set_layer(this, GtkLayerShell.Layer.OVERLAY);
                GtkLayerShell.set_keyboard_mode (this, GtkLayerShell.KeyboardMode.EXCLUSIVE);
            } else {
                this.map.connect (() => {
                   var gdkwin = this.get_window ();
                   if (gdkwin != null) {
                       var grabbed_seat = grab_inputs(gdkwin);
                       if (grabbed_seat != null) {
                           set_seat(grabbed_seat);
                       } else {
                           stderr.printf ("Failed to acquire access to input devices, aborting.");
                           app.quit();
                       }
                   }
               });
            }
        }

        public void create_practice_page(Workflow workflow){
          workflowPage = new WorkFlowPage(workflow, ()=>{
            this.remove(workflowPage);
            this.add(container);
            this.show_all();
          });
        }

        public void quit() {
            if (seat != null) seat.ungrab ();
            hide ();
            close ();
        }

        public void set_seat(Gdk.Seat seat) {
            linux_onboarding.seat = seat;
        }

        // Escape can quit while a workflow is mid-flight, so make sure no binding
        // mode is left installed in the WM's config.d.
        private void clean_config() {
            WmModeBackend.cleanup_stale_state ();
        }

        // Grabs the input devices for a given window
        private Gdk.Seat ? grab_inputs (Gdk.Window gdkwin) {
            var display = gdkwin.get_display ();
            if (display == null) {
                stderr.printf ("Failed to get Display\n");
                return null;
            }

            var seat = display.get_default_seat ();
            if (seat == null) {
                stdout.printf ("Failed to get Seat from Display\n");
                return null;
            }

            int attempt = 0;
            Gdk.GrabStatus ? grabStatus = null;
            int wait_time = 1000;

            do {
                grabStatus = seat.grab (gdkwin, Gdk.SeatCapabilities.KEYBOARD | Gdk.SeatCapabilities.POINTER, true, null, null, null);
                if (grabStatus != Gdk.GrabStatus.SUCCESS) {
                    attempt++;
                    wait_time = wait_time * 2;
                    GLib.Thread.usleep (wait_time);
                }
            } while (grabStatus != Gdk.GrabStatus.SUCCESS && attempt < 8);

            if (grabStatus != Gdk.GrabStatus.SUCCESS) {
                stderr.printf ("Aborting, failed to grab input: %d\n", grabStatus);
                return null;
            } else {
                return seat;
            }
        }
    }
}
