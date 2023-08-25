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

namespace regolith_onboarding{

  public class configManager{
    
    public configManager(){

    }
    
    public  string format_spec (string raw_keybinding) {
        // TODO: this won't work for keybindings with < > characters
        return raw_keybinding
                .replace ("<", "")
                .replace (">", " ")
                .replace ("  ", " ");
    }
    public  string format_spec_display (string raw_keybinding) {
        // TODO: this won't work for keybindings with < > characters
        return raw_keybinding
                .replace ("<", " ")
                .replace (">", " ");
    }
  }  
}
