public class MainWindow : Gtk.Window {
    public MainWindow() {
        // Set up the window
        this.title = "My Window";
        this.set_default_size(800, 600);
        this.destroy.connect(Gtk.main_quit);

        // Create a box container
        var box = new Gtk.Box(Orientation.VERTICAL, 0);
        this.set_child(box);

        // Create some widgets
        var label = new Gtk.Label("Hello, World!");
        var button = new Gtk.Button.with_label("Click me!");

        // Add widgets to the box
        box.add(label);
        box.add(button);

        // Show all the widgets individually
        label.show();
        button.show();

        // Show the window
        this.show();
    }
}
