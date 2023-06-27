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

    public class DialogWindow : Gtk.Window{

        // Reference to all active dialog pages
        private Dialog[] dialog_pages;
        // The total number of pages (including help)
        private int total_pages = -1;
        // Specifies the array index for dialog_pages of active page
        private uint active_page = 0;
        // Controls access to keyboard and mouse
        protected Gdk.Seat seat;
        // Settings backend
        private GLib.Settings settings;
        // Mode switcher
        private Gtk.Notebook notebook;

        

        public DialogWindow(){
            Object(type: Gtk.WindowType.POPUP); // Window is unmanaged
            window_position = WindowPosition.CENTER_ALWAYS;

            //settings = new GLib.Settings ("org.regolith-linux.onboarding");
            set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));
            
            // Exit if focus leaves us
            focus_out_event.connect (() => {
                quit ();
                return false;
            });
            
            notebook = new Notebook ();
            notebook.get_style_context ().add_class ("notebook");
            notebook.set_tab_pos (PositionType.BOTTOM);
            // Route keys based on function
            key_press_event.connect ((key) => {
                // Enable page nav keybindings in all page mode.
                if ((key.state & Gdk.ModifierType.MOD1_MASK) == Gdk.ModifierType.MOD1_MASK) { //ALT
                    // we need to handle shortcuts.
                    if (key.keyval == '+') { // Expand dialog
                        change_size(128);
                        return true;
                    }
                    if (key.keyval == '-') { // Contract dialog
                        change_size(-128);
                        return true;
                    }
                    
                }
                return true;
            });
        }
        
        public override void show_all() {
            base.show_all();
            notebook.set_current_page ((int) active_page);
            notebook.switch_page.connect (on_page_switch);
        }
        public void set_seat(Gdk.Seat seat) {
            this.seat = seat;
        }
        public void quit() {
            if (seat != null) seat.ungrab ();
            hide ();
            close ();
        }

        void on_page_switch (Widget? page, uint page_num) {
            if (page_num == total_pages) { // On help page
                // entry.set_sensitive (false);
            } else if (dialog_pages[page_num] != null) {
                active_page = page_num;

                // entry.secondary_icon_name = dialog_pages[active_page].get_icon_name ();
                // entry.set_sensitive (true);
            }
            dialog_pages[active_page].show();
        }
        void change_size(int delta) {
            int width, height;
            get_size(out width, out height);

            width += delta;
            height += delta;

            // Ignore changes past min bounds
            if (width < MIN_WINDOW_WIDTH || height < MIN_WINDOW_HEIGHT) return;

            var monitor = this.get_screen ().get_display ().get_monitor (0); //Assume first monitor
            if (monitor != null) {
                var geometry = monitor.get_geometry ();

                if (width >= geometry.width || height >= geometry.height) return;
            }

            resize (width, height);

            settings.set_int("window-width", width);
            settings.set_int("window-height", height);
        }
    }
}