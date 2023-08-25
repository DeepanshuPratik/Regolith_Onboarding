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

namespace regolith_onboarding{

  public class HandleScreenMode {
    private Gdk.Rectangle workarea;
    private string mode;
    public HandleScreenMode(Gtk.Window window,string mode, int x, int y){
      var gdk_window = window.get_window ();
      this.mode = mode;
      switch (mode) {
        case "WINDOW": {
          if (IS_SESSION_WAYLAND) {
            GtkLayerShell.set_anchor(window, GtkLayerShell.Edge.TOP,false);
            window.set_size_request (800, 450);
            window.resize (1, 1);
          }
          else {
            workarea = {0};
            var d = Gdk.Display.get_default ();
            var monitor = d.get_monitor_at_window (gdk_window);
            workarea = monitor.get_workarea ();
            gdk_window.move_resize (x , workarea.height/2 - 255, 800, 450);
           // gdk_window.move_resize (workarea.width+workarea.width/2 - 400 , workarea.height/2 - 225, 800, 450);
          }
          break;
        }
        case "TILEUP":{
          if (IS_SESSION_WAYLAND) {
            GtkLayerShell.set_anchor(window, GtkLayerShell.Edge.TOP,true);
            window.set_size_request (200, 150);
            window.resize (1, 1);
          } else {
            stdout.printf("\n Workspace: %s  %d : %d \n",mode, x,y);
            workarea = {0};
            var d = Gdk.Display.get_default ();
            var monitor = d.get_monitor_at_window (gdk_window);
            workarea = monitor.get_workarea ();
            gdk_window.move_resize (x+300, 0, 200, 150);
          }
          break;
        }
        default: 
          window.set_position(Gtk.WindowPosition.CENTER);
          break;
      }
    }
    public string get_mode(){
      return mode;
    }
  }
}
