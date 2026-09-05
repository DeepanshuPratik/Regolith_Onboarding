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
     * The first page: whose desktop this is.
     *
     * Every string and image here comes from the compiled-in branding bundle, so
     * a distro rebrands by rebuilding with its own -Dbranding_dir rather than by
     * patching this file.
     */
    public class IntroPage : Box {

        private const int LOGO_SIZE = 128;

        public delegate void NextPage();

        public IntroPage (owned NextPage nextPage) {
            Object(orientation: Gtk.Orientation.VERTICAL, spacing: 20);
            this.set_halign(Gtk.Align.CENTER);
            this.set_valign(Gtk.Align.CENTER);
            this.get_style_context().add_class("intro-page");

            var css_provider = new Gtk.CssProvider();
            css_provider.load_from_resource(APP_PATH + "/css/introPage.css");
            Gtk.StyleContext.add_provider_for_screen(this.get_screen(), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);

            var branding = Branding.get_default ();

            if (branding.logo_resource != "") {
                try {
                    var logo = new Gtk.Image.from_pixbuf (
                        new Gdk.Pixbuf.from_resource (branding.logo_resource)
                            .scale_simple (LOGO_SIZE, LOGO_SIZE, Gdk.InterpType.BILINEAR));
                    logo.margin_bottom = 24;
                    this.add (logo);
                } catch (Error e) {
                    warning ("Cannot load branding logo: %s", e.message);
                }
            }

            var title = new Label("Welcome to " + branding.name);
            title.get_style_context().add_class("title-main");
            title.wrap = true;
            title.justify = Gtk.Justification.CENTER;
            this.add(title);

            if (branding.tagline != "") {
                var subtitle = new Label(branding.tagline);
                subtitle.get_style_context().add_class("text-secondary");
                subtitle.wrap = true;
                subtitle.max_width_chars = 52;
                subtitle.justify = Gtk.Justification.CENTER;
                this.add(subtitle);
            }

            var start_button = new Button.with_label("Get Started");
            start_button.set_halign(Gtk.Align.CENTER);
            start_button.get_style_context().add_class("pill-button");
            start_button.get_style_context().add_class("suggested-action");
            start_button.clicked.connect(() => {
                nextPage();
            });
            this.add(start_button);
        }
    }
}
