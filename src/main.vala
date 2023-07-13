using Gtk;


int main(string[] args) {
    
    Gdk.init(ref args);

    var introWindow = new regolith_onboarding.DialogWindow();
    introWindow.show_all();
    Gdk.Window gdkwin = introWindow.get_window ();
    var seat = grab_inputs (gdkwin);
    if (seat == null) {
        stderr.printf ("Failed to aquire access to input devices, aborting.");
        return 1;
    }
    introWindow.set_seat (seat);

    // Handle mouse clicks by determining if a click is in or out of bounds
    // If we get a mouse click out of bounds of the window, then center it to the screen of application.
    introWindow.button_press_event.connect ((event) => {
        int window_width = 0, window_height = 0;
        introWindow.get_size (out window_width, out window_height);

        int mouse_x = (int) event.x;
        int mouse_y = (int) event.y;

        var click_out_bounds = ((mouse_x < 0 || mouse_y < 0) || (mouse_x > window_width || mouse_y > window_height));

        if (click_out_bounds) {
            event.x = window_width/2;
            event.y = window_height/2;
        }

        return !click_out_bounds;
    });

    Gtk.main();
    
    return 0;
}

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

