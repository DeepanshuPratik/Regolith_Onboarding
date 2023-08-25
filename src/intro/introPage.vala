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

            // adding css file
            //  var cssProvider = new Gtk.CssProvider ();
            //  cssProvider.load_from_path ("intro_window.css");
             
            var screen = this.get_screen ();
            var css_provider = new Gtk.CssProvider();
            string css_path = File.new_for_path("../src/intro/introPage.css").get_path();
            stdout.printf(css_path); 
            if (FileUtils.test (css_path, FileTest.EXISTS)) {
              try {
                css_provider.load_from_path(css_path);
                Gtk.StyleContext.add_provider_for_screen(screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
              } catch (Error e) {
                error ("Cannot load CSS stylesheet: %s", e.message);
              }
            }
            
            this.set_orientation(Gtk.Orientation.VERTICAL);
            this.set_spacing(30);
            this.get_style_context().add_class("intro_page");
            this.set_halign(Gtk.Align.CENTER);
            var container = new Box(Gtk.Orientation.VERTICAL, 5);
            this.add(container);
            
            this.set_margin_top (40);
            var image = new Gtk.Image.from_file(resource_path+"/regolith-onboarding_logo.png");
            Gdk.Pixbuf pixbuf = image.get_pixbuf();
            var img = new Gtk.Image.from_pixbuf(pixbuf.scale_simple (200, 200,Gdk.InterpType.BILINEAR));
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

            
            var button_icon = new Gtk.Image.from_file(resource_path+"/arrow-circle-right.png");
            next_button.set_image(button_icon);
            next_button.set_always_show_image(true);
            int h,l;
            next_button.get_size_request(out l, out h);
            //stdout.printf("%d %d",l,h);
            this.add(next_button);

        }
        
    }
}
