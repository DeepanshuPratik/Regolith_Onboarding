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


    public class CarouselSetup : Window {

        // Navigation stays off so a stray scroll cannot jump pages mid-practice.
        private const bool ALLOW_CAROUSEL_GESTURES = false;

        // One size for the window, whichever desktop it is on.
        private const int WINDOW_WIDTH  = 900;

        /**
         * 620 rather than 560 because the catalogue is what needs the room: five
         * tiles in two rows plus their captions, a heading and the page
         * indicator. At 560 the second row was inside a scroll view the user had
         * no reason to suspect, so the bottom row read as cut off.
         */
        private const int WINDOW_HEIGHT = 620;

        private Gtk.Box container;
        private Hdy.Carousel carousel;
        private WorkFlowPage workflowPage;
        private Gee.List<Workflow> workflows;

        // Observation, for the whole run rather than for one workflow. Built
        // last in the constructor and taken down again by release_practice().
        private PracticeSession practice;

        // Carousel contents in order: welcome, featured slides, workflow list.
        private Gee.ArrayList<Gtk.Widget> pages = new Gee.ArrayList<Gtk.Widget> ();

        // Kept so the deck can decide, once its pages exist, whether there is
        // anything worth indicating.
        private Hdy.CarouselIndicatorDots carousel_indicator;

        private OnboardingState state;

        // The first page in the deck, kept so that show_all() can wait for it to
        // paint (#33). Null when a distro ships neither a welcome page nor any
        // slides, which is a legitimate build.
        private SlidePage? first_deck_page = null;

        // How long the window waits for that first paint before showing itself
        // anyway. Long enough for a bundled page over the app:// scheme, short
        // enough that a wedged web process costs a beat rather than the app.
        private const uint FIRST_PAINT_TIMEOUT_MS = 1500;

        private bool shown_once = false;
        private uint first_paint_timeout_id = 0;

        // Last page the deck owes this user: the final slide it decided to show,
        // or the welcome page when the delta is empty. Reaching it is what marks
        // the branding version seen.
        private int last_owed_index = -1;

        public CarouselSetup (Gtk.Application app) {
            Object(application: app, type: Gtk.WindowType.POPUP);
            window_position = WindowPosition.CENTER;

            size_window ();

            // load_from_resource() does not throw in GTK3; a missing resource is a
            // build error, not something to handle at runtime.
            var css_provider = new Gtk.CssProvider();
            css_provider.load_from_resource(APP_PATH + "/css/app.css");
            Gtk.StyleContext.add_provider_for_screen(this.get_screen(), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
            // Beneath both of the above in priority: the desktop's own accent,
            // as defaults that app.css consumes and a distro's theme.css may
            // override (#32).
            Palette.apply (this.get_screen ());

            // Distro theme layers over the base sheet, so it must load after it.
            Branding.get_default ().apply_theme (this.get_screen ());

            this.get_style_context().add_class("carousel");

            container = new Box(Gtk.Orientation.VERTICAL, 30);
            container.hexpand = true;
            container.vexpand = true;
            container.get_style_context().add_class("main-container");
            this.add(container);

            carousel = new Hdy.Carousel();
            container.add(carousel);

            carousel_indicator = new Hdy.CarouselIndicatorDots();
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
            // Per desktop (#31): the same machine gets its own record on
            // Regolith and on GNOME, because the deck introduces a catalogue and
            // a practice loop that differ between them.
            state = OnboardingState.load (PlatformRegistry.probe ().primary_desktop ());
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
            // The 100-pixel gap is the "there's another page" hint the deck
            // relies on. Per-page GdkWindows created by libhandy are not
            // clipped to their allocation by default, so wider deck content
            // (longer ks, wider kbd chips) would otherwise paint across the
            // gap into the visible window — see SlidePage.build(). With that
            // clip in place, the spacing is purely visual.
            carousel.set_spacing(100);

            // Welcome plus the catalogue is not a deck, and two faint dots under
            // it read as a stray mark rather than as progress. The indicator
            // earns its place only when there is a slide to page through — which
            // on most runs, after the version has been recorded once, there is
            // not.
            if (pages.size < 3) {
                carousel_indicator.no_show_all = true;
                carousel_indicator.hide ();
            }

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
            }

            // Every other session — Wayland without a layer shell (GNOME/Mutter),
            // and X11 — configures nothing here, and neither one grabs.
            //
            // Layer shell is not merely unavailable on Mutter, it is fatal:
            // asking for any of the calls above is a SIGABRT at show_all()
            // rather than a degraded window (#26, and LayerShellSupport for the
            // measurements).
            //
            // The X11 branch used to take a KEYBOARD | POINTER seat grab the
            // moment the window mapped, and abort startup if it failed. Three
            // things were wrong with that. It asked for POINTER, which on an
            // XWayland connection into Mutter or KWin is the one thing that
            // stops GTK requesting the shortcuts inhibitor at all (#11) — so the
            // app held the pointer and lost the capability the grab was for. It
            // held the user's keyboard for the whole run, including while they
            // were reading slides and had asked for nothing. And a failed grab
            // killed the app, when the honest consequence is only that practice
            // is unavailable. PracticeSession owns the grab now, on every
            // desktop: taken at PLAY, keyboard only, dropped when the workflow
            // ends (#29).

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
         * How big this window is, and why it is not one call.
         *
         * A layer surface has no size negotiation: the compositor gives it what
         * it asks for, so sway needs a size *request* or the surface has no size
         * at all. An ordinary toplevel does negotiate, and there a size request
         * is a **minimum** — the window still grows to whatever its content
         * wants. That is what made the app 800x505 on GNOME while asking for
         * 800x450, with the content centred inside and a band of empty space
         * down each side.
         *
         * So: request on the layer-shell path, default size everywhere else,
         * where it is a starting size the user can then resize away from.
         *
         * Asked of LayerShellSupport rather than of is_wayland(), because
         * "Wayland" is not the question — GNOME and KDE are Wayland too, and
         * they are the sessions this gets wrong.
         */
        private void size_window () {
            if (PlatformRegistry.probe ().is_wayland () && LayerShellSupport.available ()) {
                set_size_request (WINDOW_WIDTH, WINDOW_HEIGHT);
            } else {
                set_default_size (WINDOW_WIDTH, WINDOW_HEIGHT);
            }
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
            if (first_deck_page == null) first_deck_page = page;
            pages.add (page);
        }

        /**
         * Show the window once there is something in it to see.
         *
         * The app used to open as a white box: show_all() ran the moment the
         * constructor returned, while every deck page was still loading, so the
         * first frame was a WebView with no document in it (#33). Waiting for the
         * first page's ready signal costs a few hundred milliseconds of nothing
         * on screen and buys a first frame that is the actual deck.
         *
         * The timeout is not optional. A page that never finishes — a broken
         * bundle, a web process that will not start — must not leave the app
         * running with no window and no explanation, so whichever comes first
         * wins and show_all() happens either way.
         *
         * Note this is only the *map*. Everything order-sensitive already
         * happened in the constructor: gtk-layer-shell must be initialised before
         * the window is mapped (#26 — asking for it on Mutter is a SIGABRT, not a
         * degraded window), and it is, whether the map comes now or in a second.
         */
        public void show_when_ready () {
            if (first_deck_page == null) {
                show_deck_now ();
                return;
            }

            first_deck_page.ready.connect (show_deck_now);
            first_paint_timeout_id = Timeout.add (FIRST_PAINT_TIMEOUT_MS, () => {
                first_paint_timeout_id = 0;
                show_deck_now ();
                return Source.REMOVE;
            });
        }

        /**
         * Whichever of the two paths above arrives first, and only that one.
         *
         * Both are dropped here rather than left to fire into a window that has
         * already been shown — or destroyed. A pending timeout holds a reference
         * to this window for as long as it is armed, which is the pattern
         * SeatGrabObserver follows next door with cancel_regrab_timeout().
         */
        private void show_deck_now () {
            if (shown_once) return;
            shown_once = true;

            if (first_paint_timeout_id != 0) {
                GLib.Source.remove (first_paint_timeout_id);
                first_paint_timeout_id = 0;
            }
            if (first_deck_page != null) first_deck_page.ready.disconnect (show_deck_now);

            show_all ();
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

        // Belt and braces behind release_practice(): that undoes what this run
        // installed, this sweeps up anything a run that was killed left behind, in
        // every platform that claims the session rather than only the one we used.
        private void clean_config() {
            PlatformRegistry.cleanup_stale_state ();
        }

    }
}
