using Gtk;

namespace regolith_onboarding {
    public const int KEY_CODE_ESCAPE = 65307;
    public const int KEY_CODE_LEFT_ALT = 65513;
    public const int KEY_CODE_RIGHT_ALT = 65514;
    public const int KEY_CODE_SUPER = 65515;
    public const int KEY_CODE_UP = 65364;
    public const int KEY_CODE_DOWN = 65362;
    public const int KEY_CODE_ENTER = 65293;
    public const int KEY_CODE_PGDOWN = 65366;
    public const int KEY_CODE_PGUP = 65365;
    public const int KEY_CODE_RIGHT = 65363;
    public const int KEY_CODE_LEFT = 65361;
    public const int KEY_CODE_PLUS = 43;
    public const int KEY_CODE_MINUS = 45;
    public const int KEY_CODE_PRINTSRC = 65377;
    public const int KEY_CODE_BRIGHT_UP = 269025026;
    public const int KEY_CODE_BRIGHT_DOWN = 269025027;
    public const int KEY_CODE_MIC_MUTE = 269025202;
    public const int KEY_CODE_VOLUME_UP = 269025043;
    public const int KEY_CODE_VOLUME_DOWN = 269025041;
    public const int KEY_CODE_VOLUME_MUTE = 269025042;
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

            // adding cross button
            var button = new Button();
            button.set_label("X");
            button.clicked.connect(on_button_clicked);
            
            box.add(button);
            var image = new Gtk.Image.from_file("/home/deepanshupratik/GSOC_2023/Regolith_Onboarding/resources/regolith-onboarding_logo.png");
            Gdk.Pixbuf pixbuf = image.get_pixbuf();
            var img = new Gtk.Image.from_pixbuf(pixbuf.scale_simple (200, 200,Gdk.InterpType.BILINEAR));
            box.add(img);
            var circle_button = new Button();
            circle_button.get_style_context().add_class("circular");
            var progressbar = new Box(Gtk.Orientation.HORIZONTAL, 5);
            circle_button.set_size_request(20, 20);
            progressbar.add(circle_button);
            progressbar.add(circle_button);
            progressbar.add(circle_button);

            var introText = new Gtk.Label("Getting started with regolith");
            introText.get_style_context().add_class("suggested-action");
            //introText.get_style_context ().add_provider (cssProvider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
            box.add(introText);
            box.add(progressbar);

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
                    this.set_opacity (0.8);
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
