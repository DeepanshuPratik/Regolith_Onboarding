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

namespace regolith_onboarding {
    
    public class IntroPage : Box {
        public const int KEY_CODE_ESCAPE = 65307;
        public delegate void NextPage();
         
        public IntroPage (owned NextPage nextPage) {
            Object(orientation: Gtk.Orientation.VERTICAL, spacing: 20);
            this.set_halign(Gtk.Align.CENTER);
            this.set_valign(Gtk.Align.CENTER);
            
            var css_provider = new Gtk.CssProvider();
            css_provider.load_from_resource(APP_PATH + "/css/introPage.css");
            Gtk.StyleContext.add_provider_for_screen(this.get_screen(), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);

            var original_pixbuf = new Gdk.Pixbuf.from_resource(APP_PATH + "/images/regolith-onboarding_logo.png");

            // 2. Create a NEW, scaled-down Pixbuf from the original data.
            //    This is the most reliable way to force a size in GTK3.
            var scaled_pixbuf = original_pixbuf.scale_simple(128, 128, Gdk.InterpType.BILINEAR);
            
            // 3. Create the Gtk.Image widget FROM the new, correctly-sized Pixbuf.
            var logo = new Gtk.Image.from_pixbuf(scaled_pixbuf);
            logo.margin_bottom = 24; // Add space below the logo

            this.add(logo);
            
            // --- Rest of the layout ---
            
            var title = new Label("Welcome to Regolith");
            title.get_style_context().add_class("title-main");
            title.wrap = true;
            title.justify = Gtk.Justification.CENTER;
            this.add(title);
            
            var subtitle = new Label("Your journey into tiling window management starts here. This guide will help you master the essentials.");
            subtitle.get_style_context().add_class("text-secondary");
            subtitle.wrap = true;
            subtitle.justify = Gtk.Justification.CENTER;
            this.add(subtitle);
            
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
