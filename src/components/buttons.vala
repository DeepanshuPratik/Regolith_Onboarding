using Gtk;

namespace regolith_onboarding {
    public class circularButton: Button {
        
        Button next_button;

        public circularButton(){
            next_button = new Button ();
            next_button.get_style_context().add_class("circular");
            next_button.set_size_request(50, 50);
            Gdk.Color white_bg; 
            Gdk.color_parse("white", out white_bg);
            next_button.modify_bg(Gtk.StateType.NORMAL, white_bg);
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