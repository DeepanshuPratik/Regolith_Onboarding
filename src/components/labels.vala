using Gtk;

namespace regolith_onboarding {
    public class introText : Label {
        
        public Label intro_text;

        public introText(){
            intro_text = new Gtk.Label("Getting started with regolith");
        }
    }
}