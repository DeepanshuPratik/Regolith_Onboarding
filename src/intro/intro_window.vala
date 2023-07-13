using Gtk;

namespace regolith_onboarding {
    const int MIN_WINDOW_WIDTH = 160;
    const int MIN_WINDOW_HEIGHT = 100;
    const float TRANSPARENCY = 0.0f;

    public class DialogWindow : Window {
        const int MIN_WINDOW_WIDTH = 160;
        const int MIN_WINDOW_HEIGHT = 100;


        // Controls access to keyboard and mouse
        protected Gdk.Seat seat;
        // grid for headers
        private Gtk.Grid grid;
        private Gtk.Box box;

        public DialogWindow () {
            Object(type: Gtk.WindowType.POPUP); // Window is unmanaged
            window_position = WindowPosition.CENTER_ALWAYS;


            // adding css file
            //  var cssProvider = new Gtk.CssProvider ();
            //  cssProvider.load_from_path ("intro_window.css");




            box = new Box(Gtk.Orientation.VERTICAL, 5);
            this.add(box);
    

            grid = new Gtk.Grid ();

            // adding close button
            var button = new Button();
            button.set_label("X");
            button.clicked.connect(on_button_clicked);
            
            box.add(button);
            var image = new Gtk.Image.from_file("/home/soumyarp/git/Regolith_Onboarding/resources/regolith-onboarding_logo.png");
            Gdk.Pixbuf pixbuf = image.get_pixbuf();
            var img = new Gtk.Image.from_pixbuf(pixbuf.scale_simple (200, 200,Gdk.InterpType.BILINEAR));
            box.add(img);

            var introText = new Gtk.Label("Getting started with regolith");
            introText.get_style_context().add_class("suggested-action");
            //introText.get_style_context ().add_provider (cssProvider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
            box.add(introText);

            Gdk.Color white_bg; 
            Gdk.color_parse("white", out white_bg);

            var circle_button = new Button();
            circle_button.get_style_context().add_class("circular");
            circle_button.set_size_request(50, 50);
            circle_button.modify_bg(Gtk.StateType.NORMAL, white_bg);


            var next_arrow = new Gtk.Image();
            next_arrow.set_from_icon_name("go-next", Gtk.IconSize.BUTTON );
            circle_button.add(next_arrow);
            box.add(circle_button);


            if (IS_SESSION_WAYLAND) {
                set_size_request (800,700);
            } else {
                set_default_size (800,700);
            }

            // changes opacity
            this.button_press_event.connect ((event) => {
                int window_width = 0, window_height = 0;
                this.get_size (out window_width, out window_height);
        
                int mouse_x = (int) event.x;
                int mouse_y = (int) event.y;
        
                var click_out_bounds = ((mouse_x < 0 || mouse_y < 0) || (mouse_x > window_width || mouse_y > window_height));
        
                if (click_out_bounds) {
                    this.set_opacity(0.8);
                }
        
                return !click_out_bounds;
            });

            // Route keys based on function
            key_press_event.connect ((key) => {
                // key.keyval
                return false;
            });

            //  entry.activate.connect (on_entry_activated);

            //  dialog_pages[active_page].show (); // Get page ready to use
        }

        private void on_button_clicked(Button button)
        {
            quit();
        }

        public void set_seat(Gdk.Seat seat) {
            this.seat = seat;
        }

        public void quit() {
            if (seat != null) seat.ungrab ();
            hide ();
            close ();
        }
    }
}
