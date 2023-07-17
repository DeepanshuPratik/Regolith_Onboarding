using Gtk;

namespace regolith_onboarding {
    
    public class IntroPage : Box {
        public const int KEY_CODE_ESCAPE = 65307;
        public delegate void NextPage();
        private File file = File.new_for_path("../resources");

        // grid for headers
        private Gtk.Grid grid;
         
        public IntroPage (owned NextPage nextPage) {

            // adding css file
            //  var cssProvider = new Gtk.CssProvider ();
            //  cssProvider.load_from_path ("intro_window.css");

            this.set_orientation(Gtk.Orientation.VERTICAL);
            this.set_spacing(30);
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
            //  var caraousel = new Hdy.Carousel();
            
            //  this.add(caraousel);
            //  var page1 = new Box(Gtk.Orientation.VERTICAL, 30);
            //  var page2 = new WorkFlows(tables);
            //  caraousel.insert(page1, 0);
            //  caraousel.insert(page2,1);
            //  caraousel.set_spacing(100);

            // disabling the drags and scrolls to next page to omit jumps while training
            //  caraousel.set_allow_scroll_wheel(allow_scroll_wheel);
            //  caraousel.set_allow_mouse_drag(allow_scroll_wheel);
            //  caraousel.set_allow_long_swipes(allow_scroll_wheel);

            grid = new Gtk.Grid ();

            this.set_margin_top (40);
            var image = new Gtk.Image.from_file(resource_path+"/regolith-onboarding_logo.png");
            Gdk.Pixbuf pixbuf = image.get_pixbuf();
            var img = new Gtk.Image.from_pixbuf(pixbuf.scale_simple (200, 200,Gdk.InterpType.BILINEAR));
            this.add(img);

            var introText = new introText();
            this.add(introText.intro_text);

            var next_button = new circularButton();
            next_button.clicked.connect(() => {
              nextPage();
            });


            var next_arrow = new Gtk.Image();
            next_arrow.set_from_icon_name("go-next", Gtk.IconSize.BUTTON );
            next_button.add(next_arrow);
            this.add(next_button);

        }
        
    }
}
