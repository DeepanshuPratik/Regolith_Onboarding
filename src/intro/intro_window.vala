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

        // Reference to all active dialog pages
        // private DialogPage[] dialog_pages;
        // The total number of pages (including help)
        private int total_pages = -1;
        // Specifies the array index for dialog_pages of active page
        private uint active_page = 0;
        // Mode switcher
        private Gtk.Notebook notebook;
        // Filtering text box
        private Gtk.Entry entry;
        

        private Gtk.Grid grid;
        // Controls access to keyboard and mouse
        protected Gdk.Seat seat;

        private Gtk.TreeView keybinding_view;

        public DialogWindow () {
            //Object(type: Gtk.WindowType.POPUP); // Window is unmanaged
            window_position = WindowPosition.CENTER_ALWAYS;

            entry = new Gtk.Entry ();
            entry.get_style_context ().add_class ("filter_entry");
            entry.hexpand = true;
            entry.button_press_event.connect ((event) => {
                // Disable context menu as causes de-focus event to exit execution
                return event.button == 3; // squelch right button click event
            });

            //entry.changed.connect (on_entry_changed);

            notebook = new Notebook ();
            notebook.get_style_context ().add_class ("notebook");
            notebook.set_tab_pos (PositionType.BOTTOM);

            
            //init_pages (arg_map, focus_page, all_page_mode);

            grid = new Gtk.Grid ();
            grid.get_style_context ().add_class ("root_box");
            grid.attach (entry, 0, 0, 1, 1);
            grid.attach (notebook, 0, 1, 1, 1);
            add (grid);

            if (IS_SESSION_WAYLAND) {
                set_size_request (600,600);
            } else {
                set_default_size (600,600);
            }


            // Exit if focus leaves us
            focus_out_event.connect (() => {
                this.set_opacity(0.6);
                return false;
            });

            // Route keys based on function
            key_press_event.connect ((key) => {
                
                bool key_handled = false;
                switch (key.keyval) {
                    case KEY_CODE_ESCAPE:
                    case KEY_CODE_SUPER:    // Explicit exit
                        quit ();
                        break;
                    case KEY_CODE_BRIGHT_UP:
                    case KEY_CODE_BRIGHT_DOWN:
                    case KEY_CODE_MIC_MUTE:
                    case KEY_CODE_VOLUME_UP:
                    case KEY_CODE_VOLUME_DOWN:
                    case KEY_CODE_VOLUME_MUTE:
                    case KEY_CODE_PRINTSRC: // Implicit exit
                        quit ();
                        break;
                    case KEY_CODE_UP:
                    case KEY_CODE_DOWN:
                    case KEY_CODE_ENTER:
                    case KEY_CODE_PGDOWN:
                    case KEY_CODE_PGUP:     // Let UI handle these nav keys
                        // show next page
                        break;
                    case KEY_CODE_RIGHT:
                    case KEY_CODE_LEFT:     // Switch pages
                        notebook.grab_focus ();
                        break;
                    default:                // Pass key event to active page for handling
                        // stdout.printf ("Keycode: %u\n", key.keyval);
                        //  key_handled = dialog_pages[active_page].key_event (key);
                        if (!key_handled) {
                            entry.grab_focus_without_selecting (); // causes entry to consume all unhandled key events
                        }
                        break;
                }

                return key_handled;
            });

            //  entry.activate.connect (on_entry_activated);

            //  dialog_pages[active_page].show (); // Get page ready to use
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
            if (width < MIN_WINDOW_WIDTH || height < MIN_WINDOW_HEIGHT) return;

            var monitor = this.get_screen ().get_display ().get_monitor (0); //Assume first monitor
            if (monitor != null) {
                var geometry = monitor.get_geometry ();

                if (width >= geometry.width || height >= geometry.height) return;
            }

            resize (width, height);
        }
        public void quit() {
            if (seat != null) seat.ungrab ();
            hide ();
            close ();
        }
    }
}
