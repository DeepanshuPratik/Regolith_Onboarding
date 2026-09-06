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

    // Held by SeatGrabObserver across its grab/ungrab cycles.
    protected Gdk.Seat seat;

    public class CarouselSetup : Window {

        // Navigation stays off so a stray scroll cannot jump pages mid-practice.
        private const bool ALLOW_CAROUSEL_GESTURES = false;

        private Gtk.Box container;
        private Hdy.Carousel carousel;
        private WorkFlowPage workflowPage;
        private Gee.List<Workflow> workflows;

        // Observation, for the whole run rather than for one workflow. Built
        // last in the constructor and taken down again by release_practice().
        private PracticeSession practice;

        // Carousel contents in order: welcome, featured slides, workflow list.
        private Gee.ArrayList<Gtk.Widget> pages = new Gee.ArrayList<Gtk.Widget> ();

        private OnboardingState state;

        // Last page the deck owes this user: the final slide it decided to show,
        // or the welcome page when the delta is empty. Reaching it is what marks
        // the branding version seen.
        private int last_owed_index = -1;

        public CarouselSetup (Gtk.Application app) {
            Object(application: app, type: Gtk.WindowType.POPUP);
            window_position = WindowPosition.CENTER;

            if (PlatformRegistry.probe ().is_wayland ()) {
                set_size_request (800,450);
            } else {
                set_default_size (800,450);
            }

            // load_from_resource() does not throw in GTK3; a missing resource is a
            // build error, not something to handle at runtime.
            var css_provider = new Gtk.CssProvider();
            css_provider.load_from_resource(APP_PATH + "/css/app.css");
            Gtk.StyleContext.add_provider_for_screen(this.get_screen(), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
            // Distro theme layers over the base sheet, so it must load after it.
            Branding.get_default ().apply_theme (this.get_screen ());

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

            // Welcome page first, then the distro's featured slides, then the
            // workflow catalogue. Welcome and slides are both HTML rendered by
            // SlidePage, so the whole deck shares one WebKit process.
            var branding = Branding.get_default ();

            // The welcome page carries its own "Get Started" in markup, which
            // moves one page along — the first slide when there are any, and the
            // catalogue when the distro ships none.
            if (branding.welcome_resource != "")
                add_deck_page (new SlidePage.self_navigating (branding.welcome_resource));

            // Version gating (D12): only the slides added since the branding
            // version this user last saw. A machine with no state file has seen
            // nothing, so it gets all of them. The deck can collapse to nothing
            // here, and that is the normal case on a run with no upgrade —
            // welcome still shows, and its "Get Started" lands on the catalogue
            // because next is resolved from the firing page, not from a fixed
            // slide count.
            state = OnboardingState.load ();
            var slides = branding.slides_for (state.last_seen_version);
            for (int i = 0; i < slides.length; i++) {
                int index = pages.size;
                add_deck_page (new SlidePage (
                    slides[i],
                    i == slides.length - 1,
                    () => { scroll_to_page (index - 1); },
                    () => { scroll_to_page (index + 1); }));
            }

            last_owed_index = pages.size - 1;
            pages.add (worflowsListPage);

            for (int i = 0; i < pages.size; i++)
                carousel.insert (pages[i], i);
            carousel.set_spacing(100);

            record_version_once_deck_is_seen ();

            carousel.set_allow_scroll_wheel(ALLOW_CAROUSEL_GESTURES);
            carousel.set_allow_mouse_drag(ALLOW_CAROUSEL_GESTURES);
            carousel.set_allow_long_swipes(ALLOW_CAROUSEL_GESTURES);

            // Escape is a way out from anywhere in the app, including mid-practice,
            // so it goes through the same teardown as every other exit.
            key_press_event.connect ((key) => {
                if (key.keyval == KEY_CODE_ESCAPE) quit();
                return false;
            });

            var is_wayland = PlatformRegistry.probe ().is_wayland ();

            if (is_wayland && LayerShellSupport.available ()) {
                // sway and any other compositor carrying zwlr_layer_shell_v1.
                // EXCLUSIVE is how this window holds the keyboard during
                // practice: the compositor routes every key here, including the
                // modifier combinations it would otherwise have eaten itself.
                GtkLayerShell.init_for_window (this);
                GtkLayerShell.set_layer(this, GtkLayerShell.Layer.OVERLAY);
                GtkLayerShell.set_keyboard_mode (this, GtkLayerShell.KeyboardMode.EXCLUSIVE);
            } else if (is_wayland) {
                // Wayland without layer shell — GNOME/Mutter is the case that
                // matters. Asking for any of the above here is not a degraded
                // experience, it is a SIGABRT at show_all(); see
                // LayerShellSupport for the measurements.
                //
                // ==> This branch is deliberately empty, and it is NOT finished. <==
                //
                // Holding the keyboard is a real capability that this session now
                // simply does not have, so practice cannot capture a keypress
                // here. Filling it is issue #14: a keyboard-only seat grab, which
                // is what plays the role EXCLUSIVE plays above. Until #14 lands,
                // an empty branch is the correct behaviour — the window opens,
                // the deck and the workflow catalogue work, and the registry
                // hands practice a null observer that explains itself — but do
                // not read the emptiness as "nothing is needed here".
            } else {
                this.map.connect (() => {
                   var gdkwin = this.get_window ();
                   if (gdkwin != null) {
                       var grabbed_seat = grab_inputs(gdkwin);
                       if (grabbed_seat != null) {
                           set_seat(grabbed_seat);
                       } else {
                           stderr.printf ("Failed to acquire access to input devices, aborting.");
                           // app.quit() destroys no windows, so nothing else here
                           // would run; tear down first, then ask to exit.
                           quit();
                           app.quit();
                       }
                   }
               });
            }

            // Last, so the window is fully configured before an observer starts
            // reading its key events, and after the Escape handler above so that
            // handler still runs first.
            //
            // This window is the observer's owner because it is the only widget
            // here whose life is the app's: a grab-based observer hooks the
            // owner's key events and holds a grab on its Gdk.Window, and a
            // practice page — which comes and goes with each workflow — would
            // take both away with it. It is also where GTK delivers key events
            // before propagating them to whatever currently has focus.
            practice = new PracticeSession (this, workflows);

            // Writes the binding mode now rather than at PLAY. A config reload
            // before the window is even mapped is invisible; the same reload in
            // the middle of a workflow is a flicker over the thing being taught.
            practice.install ();

            // The window can also be destroyed without going through quit() — a
            // window-manager close, or the toplevel being torn down at exit. Left
            // uninstalled, the binding mode shadows the user's keys until some
            // later run's cleanup_stale_state() notices it.
            this.destroy.connect (release_practice);
        }

        /**
         * Appends an HTML page and wires its action links up to where it sits.
         * Positions are resolved at click time and relative to the page that
         * fired, so the same <a href="app://action/next"> works wherever a
         * distro puts it in the deck.
         */
        private void add_deck_page (SlidePage page) {
            int index = pages.size;
            page.action.connect ((name) => { dispatch_action (name, index); });
            pages.add (page);
        }

        /**
         * The vocabulary an HTML page may use. Deliberately only positions in
         * the deck: markup replaces the buttons it used to sit beside, and can
         * reach nothing the buttons could not.
         */
        private void dispatch_action (string name, int from_index) {
            switch (name) {
                case "next":      scroll_to_page (from_index + 1);  break;
                case "back":      scroll_to_page (from_index - 1);  break;
                case "catalogue": scroll_to_page (pages.size - 1);  break;
                default:
                    warning ("branding page asked for app://action/%s, " +
                             "which this build does not implement", name);
                    break;
            }
        }

        /**
         * Marks the branding version seen once the user has reached the last page
         * the deck owed them.
         *
         * Not at startup, which is the tempting place for it: a user who opens the
         * window and closes it on slide two would then never be shown slide three,
         * and the app would have quietly eaten content it exists to deliver.
         * Reaching the final owed page is the earliest moment the claim "this user
         * has seen this version" is actually true.
         *
         * A user who jumps straight to the catalogue from the welcome page is
         * therefore not recorded, and sees the same slides next launch. That is
         * the right direction to be wrong in: showing a slide twice is a small
         * annoyance, never showing it is the bug.
         */
        private void record_version_once_deck_is_seen () {
            var branding = Branding.get_default ();

            // The carousel opens on page 0, so nothing beyond it being owed means
            // there is nothing left for the user to miss — the no-delta case, and
            // the one where a distro ships no slides at all.
            if (last_owed_index <= 0) {
                state.record (branding.version);
                return;
            }

            carousel.page_changed.connect ((index) => {
                if ((int) index >= last_owed_index) state.record (branding.version);
            });
        }

        private void scroll_to_page (int index) {
            if (index < 0 || index >= pages.size) return;
            carousel.scroll_to_full (pages[index], 400);
        }

        public void create_practice_page(Workflow workflow){
          workflowPage = new WorkFlowPage(workflow, practice, ()=>{
            this.remove(workflowPage);
            this.add(container);
            this.show_all();
          });
        }

        /**
         * The one way out. Every exit path funnels through here so that nothing
         * this run installed outside the process outlives it.
         */
        public void quit() {
            release_practice ();
            clean_config ();
            if (seat != null) seat.ungrab ();
            hide ();
            close ();
        }

        /**
         * Take the binding mode back out of the window manager and drop any grab
         * the observer holds. Idempotent, because more than one exit path reaches
         * it and quit() itself triggers the destroy handler that also calls it.
         */
        public void release_practice () {
            if (practice != null) practice.uninstall ();
        }

        public void set_seat(Gdk.Seat seat) {
            linux_onboarding.seat = seat;
        }

        // Belt and braces behind release_practice(): that undoes what this run
        // installed, this sweeps up anything a run that was killed left behind, in
        // every platform that claims the session rather than only the one we used.
        private void clean_config() {
            PlatformRegistry.cleanup_stale_state ();
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
