using Gtk;

namespace regolith_onboarding {
    
    public class DisplayWorkFlow : Window {
        
        public DisplayWorkFlow(){
            Object(type: Gtk.WindowType.POPUP);
            window_position = WindowPosition.CENTER_ALWAYS;

            
        }
    }
}