using Gtk;

namespace regolith_onboarding {
    const int MIN_WINDOW_WIDTH = 160;
    const int MIN_WINDOW_HEIGHT = 100;
    const float TRANSPARENCY = 0.0f;

    public class DialogWindow : Window {
        public const int KEY_CODE_ESCAPE = 65307;
        const int MIN_WINDOW_WIDTH = 160;
        const int MIN_WINDOW_HEIGHT = 100;


        // Controls access to keyboard and mouse
        protected Gdk.Seat seat;
        // grid for headers
        private Gtk.Grid grid;

        public DialogWindow () {
            Object(type: Gtk.WindowType.POPUP); // Window is unmanaged
            window_position = WindowPosition.CENTER_ALWAYS;


            // adding css file
            //  var cssProvider = new Gtk.CssProvider ();
            //  cssProvider.load_from_path ("intro_window.css");


            var container = new Box(Gtk.Orientation.VERTICAL, 5);
            this.add(container);
            var tables = new HashTable<string, string>(str_hash,str_equal);
            
            // 

            File file = File.new_for_path("../resources");
            var resource_path = file.get_path();
            tables["Sessions"] = resource_path+"/floating.jpeg";
            tables["Navigation"] = resource_path+"/Navigation.jpeg";
            tables["Workspace"] = resource_path+"/workspaces.jpeg";
            tables["Modes"] = resource_path+"/resize.jpeg";
            tables["Ilia"] = resource_path+"/ilia.jpeg";
            tables["Floating Windows"] = resource_path+"/floating.jpeg";
            var caraousel = new Hdy.Carousel();
            
            container.add(caraousel);
            var page1 = new Box(Gtk.Orientation.VERTICAL, 30);
            var page2 = new Box(Gtk.Orientation.VERTICAL, 30);
            caraousel.insert(page1, 0);
            var page3 = new WorkFlows(tables);
            caraousel.insert(page2,1);
            caraousel.insert(page3,2);


            grid = new Gtk.Grid ();

            //  // adding close button
            //  var button = new Button();
            //  button.set_label("X");
            //  button.clicked.connect(on_button_clicked);
            
            // page1.add(button);
            page1.set_margin_top (40);
            var image = new Gtk.Image.from_file("/home/deepanshupratik/GSOC_2023/Regolith_Onboarding/resources/regolith-onboarding_logo.png");
            Gdk.Pixbuf pixbuf = image.get_pixbuf();
            var img = new Gtk.Image.from_pixbuf(pixbuf.scale_simple (200, 200,Gdk.InterpType.BILINEAR));
            page1.add(img);

            var introText = new Gtk.Label("Getting started with regolith");
            introText.get_style_context().add_class("suggested-action");
            //introText.get_style_context ().add_provider (cssProvider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
            page1.add(introText);

            Gdk.Color white_bg; 
            Gdk.color_parse("white", out white_bg);

            var next_button = new Button();
            next_button.get_style_context().add_class("circular");
            next_button.set_size_request(50, 50);
            next_button.modify_bg(Gtk.StateType.NORMAL, white_bg);
            next_button.clicked.connect(()=>{
                caraousel.scroll_to_full(page3,1000);
            });


            var next_arrow = new Gtk.Image();
            next_arrow.set_from_icon_name("go-next", Gtk.IconSize.BUTTON );
            next_button.add(next_arrow);
            page1.add(next_button);

            var caraousel_indicator = new Hdy.CarouselIndicatorDots();
            caraousel_indicator.set_carousel(caraousel);
            container.add(caraousel_indicator);


            if (IS_SESSION_WAYLAND) {
                set_size_request (800,450);
            } else {
                set_default_size (800,450);
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
                if(!click_out_bounds){
                    this.set_opacity(1.0);
                }
        
                return !click_out_bounds;
            });

            // Route keys based on function
            key_press_event.connect ((key) => {
                switch (key.keyval) {
                    case KEY_CODE_ESCAPE:
                        quit();
                        break;
                }
                return false;
            });

            //  entry.activate.connect (on_entry_activated);

            //  dialog_pages[active_page].show (); // Get page ready to use
        }

        //  private void on_button_clicked(Button button)
        //  {
        //      quit();
        //  }

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
