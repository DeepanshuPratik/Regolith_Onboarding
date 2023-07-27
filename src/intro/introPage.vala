using Gtk;

namespace regolith_onboarding {
    
    public class IntroPage : Box {
        public const int KEY_CODE_ESCAPE = 65307;
        public delegate void NextPage();
         
        public IntroPage (owned NextPage nextPage) {

            // adding css file
            //  var cssProvider = new Gtk.CssProvider ();
            //  cssProvider.load_from_path ("intro_window.css");
             
            var screen = this.get_screen ();
            var css_provider = new Gtk.CssProvider();
            string css_path = File.new_for_path("../src/intro/introPage.css").get_path();
            stdout.printf(css_path); 
            if (FileUtils.test (css_path, FileTest.EXISTS)) {
              try {
                css_provider.load_from_path(css_path);
                Gtk.StyleContext.add_provider_for_screen(screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
              } catch (Error e) {
                error ("Cannot load CSS stylesheet: %s", e.message);
              }
            }
            this.set_orientation(Gtk.Orientation.VERTICAL);
            this.set_spacing(30);
            var container = new Box(Gtk.Orientation.VERTICAL, 5);
            this.add(container);
            
            this.set_margin_top (40);
            var image = new Gtk.Image.from_file(resource_path+"/regolith-onboarding_logo.png");
            Gdk.Pixbuf pixbuf = image.get_pixbuf();
            var img = new Gtk.Image.from_pixbuf(pixbuf.scale_simple (200, 200,Gdk.InterpType.BILINEAR));
            this.add(img);

            var introText = new Label("Getting started with regolith"); 
            introText.get_style_context().add_class("introText");
            this.add(introText);

            var next_button = new circularButton();
            next_button.get_style_context().add_class("nextButton");
            next_button.set_size_request(10, 5);
            next_button.clicked.connect(() => {
              nextPage();
            });


            var next_arrow = new Gtk.Image();
            next_arrow.set_from_icon_name("go-next", Gtk.IconSize.BUTTON );
            next_arrow.set_size_request(10,5);
            next_button.add(next_arrow);
            int h,l;
            next_button.get_size_request(out l, out h);
            //stdout.printf("%d %d",l,h);
            this.add(next_button);

        }
        
    }
}
