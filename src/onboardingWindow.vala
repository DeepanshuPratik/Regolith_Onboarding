using Gtk;

namespace regolith_onboarding {
    const int MAX_WINDOW_WIDTH = 1200;
    const int MAX_WINDOW_HEIGHT = 800;
    const int MIN_WINDOW_WIDTH = 200;
    const int MIN_WINDOW_HEIGHT = 100;
    bool allow_scroll_wheel = false;
    private string resource_path;
    protected Hdy.Carousel carousel;
    private uint carousel_spacing;
    
    // Controls access to keyboard and mouse
    protected Gdk.Seat seat;

    public class CarouselSetup : Window {
        public const int KEY_CODE_ESCAPE = 65307;
        const int MIN_WINDOW_WIDTH = 160;
        const int MIN_WINDOW_HEIGHT = 100;
        private File file = File.new_for_path("../resources");
        // Controls access to keyboard and mouse
        protected Gdk.Seat seat;

        public CarouselSetup () {

            Object(type: Gtk.WindowType.POPUP); // Window is unmanaged
            window_position = WindowPosition.CENTER_ALWAYS;

            if (IS_SESSION_WAYLAND) {
                set_size_request (800,450);
            } else {
                set_default_size (800,450);
            }

            var container = new Box(Gtk.Orientation.VERTICAL, 30);
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
            var carousel = new Hdy.Carousel();

            // adding carrousel and indicators
            container.add(carousel);
            var carousel_indicator = new Hdy.CarouselIndicatorDots();
            carousel_indicator.set_carousel(carousel);
            container.add(carousel_indicator);

            var worflowsListPage = new WorkFlows(tables);
            var introPage = new IntroPage( ()=>{
                carousel.scroll_to_full(worflowsListPage,800);
            });
            carousel.insert(introPage, 0);
            carousel.insert(worflowsListPage,1);
            carousel_spacing = 100;
            carousel.set_spacing(carousel_spacing);

            // disabling the drags and scrolls to next page to omit jumps while training
            carousel.set_allow_scroll_wheel(allow_scroll_wheel);
            carousel.set_allow_mouse_drag(allow_scroll_wheel);
            carousel.set_allow_long_swipes(allow_scroll_wheel);


            // Route keys based on function
            key_press_event.connect ((key) => {
                switch (key.keyval) {   // Esc for exiting the application
                    case KEY_CODE_ESCAPE:
                        quit();
                        break;
                }
                return false;
            });

            // changes opacity
            this.button_press_event.connect ((event) => {

                int window_width = 0, window_height = 0;
                this.get_size(out window_width, out window_height);
                int mouse_x = (int) event.x;
                int mouse_y = (int) event.y;
        
                var click_out_bounds = ((mouse_x < 0 || mouse_y < 0) || (mouse_x > window_width || mouse_y > window_height));
        
                if (click_out_bounds) {
                    //this.set
                    container.set_opacity(0.5);
                    seat.ungrab();
                }
                if(!click_out_bounds){
                    container.set_opacity(1.0);
                    Gdk.Window gdkwin = this.get_window ();
                    seat.grab(gdkwin, Gdk.SeatCapabilities.KEYBOARD | Gdk.SeatCapabilities.POINTER, true, null, null, null);
                }
        
                return !click_out_bounds;
            });

        }

        public void quit() {
            if (seat != null) seat.ungrab ();
            hide ();
            close ();
        }
        public void set_seat(Gdk.Seat seat) {
            this.seat = seat;
        }
    }
}

