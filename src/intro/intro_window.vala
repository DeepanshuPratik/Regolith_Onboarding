using Gtk;

namespace regolith_onboarding {
    const int MIN_WINDOW_WIDTH = 160;
    const int MIN_WINDOW_HEIGHT = 100;
    const float TRANSPARENCY = 0.0f;
    bool allow_scroll_wheel = false;
    private string resource_path;

    public class OnboardingWindow : Window {
        public const int KEY_CODE_ESCAPE = 65307;
        const int MIN_WINDOW_WIDTH = 160;
        const int MIN_WINDOW_HEIGHT = 100;
        private File file = File.new_for_path("../resources");

        // Controls access to keyboard and mouse
        protected Gdk.Seat seat;
        // grid for headers
        private Gtk.Grid grid;

        public OnboardingWindow () {
            Object(type: Gtk.WindowType.POPUP); // Window is unmanaged
            window_position = WindowPosition.CENTER_ALWAYS;


            // adding css file
            //  var cssProvider = new Gtk.CssProvider ();
            //  cssProvider.load_from_path ("intro_window.css");


            var container = new Box(Gtk.Orientation.VERTICAL, 5);
            this.add(container);
            var tables = new HashTable<string, string>(str_hash,str_equal);
            
            // resources loading
            resource_path = file.get_path();
            tables["Sessions"] = resource_path+"/floating.jpeg";
            tables["Navigation"] = resource_path+"/Navigation.jpeg";
            tables["Workspace"] = resource_path+"/workspaces.jpeg";
            tables["Modes"] = resource_path+"/resize.jpeg";
            tables["Ilia"] = resource_path+"/ilia.jpeg";
            tables["Floating Windows"] = resource_path+"/floating.jpeg";
            var caraousel = new Hdy.Carousel();
            
            container.add(caraousel);
            var page1 = new Box(Gtk.Orientation.VERTICAL, 30);
            var page2 = new WorkFlows(tables);
            var page3 = new Box(Gtk.Orientation.VERTICAL, 30);
            caraousel.insert(page1, 0);
            caraousel.insert(page2,1);
            caraousel.insert(page3,2);
            caraousel.set_spacing(100);

            // disabling the drags and scrolls to next page to omit jumps while training
            caraousel.set_allow_scroll_wheel(allow_scroll_wheel);
            caraousel.set_allow_mouse_drag(allow_scroll_wheel);
            caraousel.set_allow_long_swipes(allow_scroll_wheel);


            grid = new Gtk.Grid ();

            page1.set_margin_top (40);
            var image = new Gtk.Image.from_file(resource_path+"/regolith-onboarding_logo.png");
            Gdk.Pixbuf pixbuf = image.get_pixbuf();
            var img = new Gtk.Image.from_pixbuf(pixbuf.scale_simple (200, 200,Gdk.InterpType.BILINEAR));
            page1.add(img);

            var introText = new introText();
            //introText.get_style_context ().add_provider (cssProvider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
            page1.add(introText.intro_text);

            var next_button = new circularButton();
            next_button.clicked.connect(()=>{
                caraousel.scroll_to_full(page2,800);
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
                    seat.ungrab ();
                }
                if(!click_out_bounds){
                    this.set_opacity(1.0);
                    Gdk.Window gdkwin = this.get_window ();
                    seat.grab(gdkwin, Gdk.SeatCapabilities.KEYBOARD | Gdk.SeatCapabilities.POINTER, true, null, null, null);
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
