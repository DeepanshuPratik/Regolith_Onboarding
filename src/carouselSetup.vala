using Gtk;

namespace regolith_onboarding {
    const int MAX_WINDOW_WIDTH = 1200;
    const int MAX_WINDOW_HEIGHT = 800;
    const int MIN_WINDOW_WIDTH = 200;
    const int MIN_WINDOW_HEIGHT = 100;
    const float TRANSPARENCY = 0.0f;
    bool allow_scroll_wheel = false;
    private string resource_path;
    protected Hdy.Carousel caraousel;
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
            var onboardingPage = new OnboardingWindow();
                //  ()=>{
                //  caraousel.scroll_to_full(worflowsListPage,800);
                //  });
            var worflowsListPage = new WorkFlows(tables);

            caraousel.insert(onboardingPage, 0);
            caraousel.insert(worflowsListPage,1);
            carousel_spacing = 100;
            caraousel.set_spacing(carousel_spacing);

            // disabling the drags and scrolls to next page to omit jumps while training
            caraousel.set_allow_scroll_wheel(allow_scroll_wheel);
            caraousel.set_allow_mouse_drag(allow_scroll_wheel);
            caraousel.set_allow_long_swipes(allow_scroll_wheel);


            // Route keys based on function
            key_press_event.connect ((key) => {
                if ((key.state & Gdk.ModifierType.MOD1_MASK) == Gdk.ModifierType.MOD1_MASK) {
                    if (key.keyval == '+') { // Expand dialog
                        carousel_spacing = carousel_spacing+200;
                        caraousel.set_spacing(carousel_spacing);
                        change_size(60);
                        return true;
                    }
                    if (key.keyval == '-') { // Contract dialog
                        carousel_spacing = carousel_spacing-50;
                        caraousel.set_spacing(carousel_spacing);
                        change_size(-60);
                        return true;
                    }
                }
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
        // Resize the dialog, bigger or smaller
        void change_size(int delta) {
            int width, height;
            get_size(out width, out height);

            width += delta;
            height += delta;

            // Ignore changes past min bounds
            if (width < MIN_WINDOW_WIDTH || height < MIN_WINDOW_HEIGHT || height > MAX_WINDOW_HEIGHT || width > MAX_WINDOW_WIDTH) return;

            var monitor = this.get_screen ().get_display ().get_monitor (0); //Assume first monitor
            if (monitor != null) {
                var geometry = monitor.get_geometry ();
                if (width >= geometry.width || height >= geometry.height) return;
            }

            resize (width, height);
        }
    }
}

