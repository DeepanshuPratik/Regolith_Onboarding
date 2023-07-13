using Gtk;
using GtkLayerShell;

// Globals
bool IS_SESSION_WAYLAND;
string WM_NAME;
// Default style
char* default_css = """
                .root_box {
                    margin: 8px;
                }

                window {
                    border-style: dotted;
                    border-width: 1px;
                }

                .filter_entry {
                    border: none;
                    background: none;
                    min-height: 36px;
                    min-width: 320px;
                }

                .notebook {
                    border: none;
                }

                .keybindings {
                    font-family: monospace;
                }
            """;
/**
 * Application entry point
 */
public static int main (string[] args) {
    Gtk.init (ref args);

    // Get session type (wayland or x11) and set the flag
    string session_type = Environment.get_variable ("XDG_SESSION_TYPE");
    string gdk_backend = Environment.get_variable ("GDK_BACKEND");
    IS_SESSION_WAYLAND = session_type == "wayland" && gdk_backend != "x11";

    // Set window manager
    string sway_sock = Environment.get_variable ("SWAYSOCK");
    string i3_sock = Environment.get_variable ("I3SOCK");

    if (sway_sock != null) {
        WM_NAME = "sway";
    } else if (i3_sock != null) {
        WM_NAME = "i3";
    } else {
        WM_NAME = "Unknown";
    }
    var window = new regolith_onboarding.DialogWindow ();
    window.destroy.connect (Gtk.main_quit);

    // Grab inputs from wayland backend before showing window
    if (IS_SESSION_WAYLAND) {
        GtkLayerShell.init_for_window (window);
        GtkLayerShell.set_layer(window, GtkLayerShell.Layer.OVERLAY);
        GtkLayerShell.set_keyboard_mode (window, GtkLayerShell.KeyboardMode.EXCLUSIVE);
    }
    window.show_all();
    if (!IS_SESSION_WAYLAND) {
        Gdk.Window gdkwin = window.get_window ();
            var seat = grab_inputs (gdkwin);
            if (seat == null) {
                stderr.printf ("Failed to aquire access to input devices, aborting.");
                return 1;
            }
            window.set_seat (seat);
        }
    
        // Handle mouse clicks by determining if a click is in or out of bounds
        // If we get a mouse click out of bounds of the window, exit.
        window.button_press_event.connect ((event) => {
            int window_width = 0, window_height = 0;
            window.get_size (out window_width, out window_height);
    
            int mouse_x = (int) event.x;
            int mouse_y = (int) event.y;
    
            var click_out_bounds = ((mouse_x < 0 || mouse_y < 0) || (mouse_x > window_width || mouse_y > window_height));
    
            if (click_out_bounds) {
                window.quit ();
            }
    
            return !click_out_bounds;
        });
    
        Gtk.main ();
        
        return 0;
}
// Grabs the input devices for a given window
// Some systems exhibit behavior such that keyboard / mouse cannot be reliably grabbed.
// As a workaround, this function will continue to attempt to grab these resources over an
// increasing time window and eventually give up and exit if ultimately unable to aquire
// the keyboard and mouse resources.
Gdk.Seat ? grab_inputs (Gdk.Window gdkwin) {
    var display = gdkwin.get_display (); // Gdk.Display.get_default();
    if (display == null) {
        stderr.printf ("Failed to get Display\n");
        return null;
    }

    var seat = display.get_default_seat ();
    if (seat == null) {
        stdout.printf ("Failed to get Seat from Display\n");
        return null;
    }

    int attempt = 0;
    Gdk.GrabStatus ? grabStatus = null;
    int wait_time = 1000;

    do {
        grabStatus = seat.grab (gdkwin, Gdk.SeatCapabilities.KEYBOARD | Gdk.SeatCapabilities.POINTER, true, null, null, null);
        if (grabStatus != Gdk.GrabStatus.SUCCESS) {
            attempt++;
            wait_time = wait_time * 2;
            GLib.Thread.usleep (wait_time);
        }
    } while (grabStatus != Gdk.GrabStatus.SUCCESS && attempt < 8);

    if (grabStatus != Gdk.GrabStatus.SUCCESS) {
        stderr.printf ("Aborting, failed to grab input: %d\n", grabStatus);
        return null;
    } else {
        return seat;
    }
}

string? get_wm_cli() {
    if(WM_NAME == "i3") {
        return "/usr/bin/i3-msg ";
    } else if (WM_NAME == "sway") {
        return "/usr/bin/swaymsg ";
    }
    return null;
}
