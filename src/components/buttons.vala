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
    public class circularButton: Button {
        
        Button next_button;

        public circularButton(){
            next_button = new Button ();
            next_button.get_style_context().add_class("circular");
            // stdout.printf(regolith_onboarding.resource_path);
            //  Gdk.Color white_bg; 
            //  Gdk.color_parse("white", out white_bg);
            //  next_button.modify_bg(Gtk.StateType.NORMAL, white_bg);
        }
    }
    public class closeButton: Button {
        Button close_button;

        public closeButton(){
            close_button = new Button ();
            close_button.set_label ("X");
        }
        public void on_button_clicked(Button button)
        {
           // exit
        }
    }
}
