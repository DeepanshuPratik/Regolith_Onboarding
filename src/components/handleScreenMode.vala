
using Gtk;

namespace regolith_onboarding{

  public class HandleScreenMode {
    private Gdk.Rectangle workarea; 
    public HandleScreenMode(Gtk.Window window,string mode){
      var gdk_window = window.get_window ();
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
            gdk_window.move_resize (workarea.width+workarea.width/2 - 400 , workarea.height/2 - 225, 800, 450);
          }
          break;
        }
        case "TILEUP":{
          if (IS_SESSION_WAYLAND) {
            GtkLayerShell.set_anchor(window, GtkLayerShell.Edge.TOP,true);
            window.set_size_request (200, 150);
            window.resize (1, 1);
          } else {
            workarea = {0};
            var d = Gdk.Display.get_default ();
            var monitor = d.get_monitor_at_window (gdk_window);
            workarea = monitor.get_workarea ();
            gdk_window.move_resize (workarea.width/2-100, 0, 200, 150);
          }
          break;
        }
        default: 
          workarea = {0};
          var d = Gdk.Display.get_default ();
          var monitor = d.get_monitor_at_window (gdk_window);
          workarea = monitor.get_workarea ();
          gdk_window.move_resize (workarea.width+workarea.width/2 - 400 , workarea.height/2 - 225, 800, 450);
          break;
      }
    }
  }
}
