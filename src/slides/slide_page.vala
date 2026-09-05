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
     * One featured slide: a distro-authored HTML page with navigation beneath it.
     *
     * Slides are content, not code, so the view is locked down — scripting is off
     * unless the distro opts in via branding.conf, and navigation is confined to
     * the bundle. An external link is handed to the user's real browser rather
     * than turning this window into one.
     */
    public class SlidePage : Box {

        public delegate void Navigate ();

        private Navigate go_back;
        private Navigate go_forward;

        public SlidePage (string resource_path, bool is_last,
                          owned Navigate back, owned Navigate forward) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 8);
            this.margin = 12;
            this.go_back = (owned) back;
            this.go_forward = (owned) forward;

            SlideScheme.register ();

            var view = build_view ();
            view.expand = true;
            this.add (view);
            this.add (build_nav (is_last));

            view.load_uri (SlideScheme.uri_for (resource_path));
        }

        private WebKit.WebView build_view () {
            var view = new WebKit.WebView ();

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

                // Anything inside the bundle is fine; it is the content we shipped.
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
