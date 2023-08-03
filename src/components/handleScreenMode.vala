
using Gtk;

namespace regolith_onboarding{

  public class handleScreenMode {
    private Gdk.Rectangle workarea; 
    public handleScreenMode(Gdk.Window window,string mode){
      switch (mode) {
        case "WINDOW": {
          workarea = {0};
          var d = Gdk.Display.get_default ();
          var monitor = d.get_monitor_at_window (window);
          workarea = monitor.get_workarea ();
          window.move_resize (workarea.width+workarea.width/2 - 400 , workarea.height/2 - 225, 800, 450);
          break;
        }
        case "TILEUP":{
          workarea = {0};
          var d = Gdk.Display.get_default ();
          var monitor = d.get_monitor_at_window (window);
          workarea = monitor.get_workarea ();
          window.move_resize (workarea.width+workarea.width/2-100, 0, 200, 150);
          break;
        }
        default: 
          workarea = {0};
          var d = Gdk.Display.get_default ();
          var monitor = d.get_monitor_at_window (window);
          workarea = monitor.get_workarea ();
          window.move_resize (workarea.width+workarea.width/2 - 400 , workarea.height/2 - 225, 800, 450);
          break;
      }
    }
  }
}
