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
     * One page of the HTML deck: a distro-authored page rendered by WebKit.
     *
     * Pages are content, not code, so the view is locked down — scripting is off
     * unless the distro opts in via branding.conf, and navigation is confined to
     * the bundle. An external link is handed to the user's real browser rather
     * than turning this window into one.
     *
     * A page whose markup carries its own buttons — the welcome page does — is
     * built with SlidePage.self_navigating() and reaches the app through the
     * "action" signal rather than the Back/Next widgets beneath it.
     */
    public class SlidePage : Box {

        public delegate void Navigate ();

        /**
         * Emitted when the page follows an app://action/<name> link. This is the
         * entire callback surface an HTML page gets, and it needs no JavaScript:
         * a plain <a href> produces a navigation, and every navigation is already
         * ours to decide on.
         */
        public signal void action (string name);

        private Navigate go_back;
        private Navigate go_forward;

        /**
         * WebKit gives each WebView its own web process by default, which for a
         * short slide deck costs a couple of hundred megabytes per slide. Views
         * created as "related" to an existing one share that process instead, so
         * the whole deck runs in a single one.
         */
        private static WebKit.WebView? process_leader = null;

        public SlidePage (string resource_path, bool is_last,
                          owned Navigate back, owned Navigate forward) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 8);
            this.go_back = (owned) back;
            this.go_forward = (owned) forward;
            build (resource_path, build_nav (is_last));
        }

        /** A page whose own markup navigates, so no buttons are added under it. */
        public SlidePage.self_navigating (string resource_path) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 8);
            build (resource_path, null);
        }

        private void build (string resource_path, Gtk.Widget? nav) {
            this.margin = 12;

            SlideScheme.register ();

            var view = build_view ();
            view.expand = true;
            this.add (view);
            if (nav != null) this.add (nav);

            view.load_uri (SlideScheme.uri_for (resource_path));
        }

        private WebKit.WebView build_view () {
            var view = (process_leader == null)
                ? new WebKit.WebView ()
                : new WebKit.WebView.with_related_view (process_leader);
            if (process_leader == null) process_leader = view;

            var settings = view.get_settings ();
            settings.enable_javascript = Branding.get_default ().allow_slide_scripts;
            settings.enable_developer_extras = false;
            settings.enable_html5_database = false;
            settings.enable_html5_local_storage = false;

            view.decide_policy.connect ((decision, type) => {
                if (type != WebKit.PolicyDecisionType.NAVIGATION_ACTION &&
                    type != WebKit.PolicyDecisionType.NEW_WINDOW_ACTION)
                    return false;

                var target = ((WebKit.NavigationPolicyDecision) decision)
                                .get_navigation_action ().get_request ().get_uri ();

                // The action host must be claimed before the bundle check below,
                // or it falls through to the scheme handler, which would look it
                // up as a file and 404.
                var requested = SlideScheme.action_in (target);
                if (requested != null) {
                    decision.ignore ();
                    if (requested == "") {
                        warning ("action link names no action: %s", target);
                    } else {
                        // A handler moves the carousel and may well tear this
                        // view down, so let WebKit finish with the decision first.
                        Idle.add (() => { action (requested); return Source.REMOVE; });
                    }
                    return true;
                }

                // Anything else inside the bundle is fine; it is content we shipped.
                if (target.has_prefix (SlideScheme.SCHEME + ":")) return false;

                // Everything else leaves the app. Note this must not use
                // Gtk.show_uri_on_window(): that exports a window handle via
                // xdg-foreign for the OpenURI portal, which a gtk-layer-shell
                // surface cannot do, and the compositor kills us for trying.
                try {
                    AppInfo.launch_default_for_uri (target, null);
                } catch (Error e) {
                    warning ("Cannot open '%s': %s", target, e.message);
                }
                decision.ignore ();
                return true;
            });

            view.load_failed.connect ((ev, failing_uri, err) => {
                warning ("slide failed to load (%s): %s", failing_uri, err.message);
                return false;
            });

            return view;
        }

        private Gtk.Box build_nav (bool is_last) {
            var nav = new Box (Gtk.Orientation.HORIZONTAL, 8);
            nav.set_halign (Gtk.Align.CENTER);

            // Back always shows; from the first slide it returns to the welcome page.
            var back = new Button.with_label ("Back");
            back.get_style_context ().add_class ("cancelButton");
            back.clicked.connect (() => { go_back (); });
            nav.add (back);

            var forward = new Button.with_label (is_last ? "Get Started" : "Next");
            forward.get_style_context ().add_class ("pill-button");
            forward.get_style_context ().add_class ("suggested-action");
            forward.clicked.connect (() => { go_forward (); });
            nav.add (forward);

            return nav;
        }
    }
}
