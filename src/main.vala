using Gtk;


public class Program {
    public static int main(string[] args) {
        Gtk.init(ref args);

        var window = new MainWindow();
        Gtk.main();

        return 0;
    }
}
