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
            Object(orientation: Gtk.Orientation.VERTICAL, spacing: 30);
            var css_provider = new Gtk.CssProvider();
            css_provider.load_from_resource(APP_PATH + "/css/introPage.css");
            Gtk.StyleContext.add_provider_for_screen(this.get_screen(), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
            this.get_style_context().add_class("intro_page");
            this.set_halign(Gtk.Align.CENTER);
            this.set_margin_top (40);

            var img = new Gtk.Image.from_resource(APP_PATH + "/images/regolith-onboarding_logo.png");
            this.add(img);

            var introText = new Label("Getting started with regolith"); 
            introText.get_style_context().add_class("introText");
            this.add(introText);

            var next_button = new Button();
            next_button.get_style_context().add_class("nextButton");
            next_button.expand = false;
            next_button.clicked.connect(() => {
              nextPage();
            });

            var button_icon = new Gtk.Image.from_resource(APP_PATH + "/images/arrow-circle-right.png");
            next_button.set_image(button_icon);
            next_button.set_always_show_image(true);
            this.add(next_button);
        }
    }
}
