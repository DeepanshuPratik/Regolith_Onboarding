using Gtk;
using Gee;

namespace regolith_onboarding {
    
    public class WorkFlows : Box {
        protected Gdk.Seat seat;
        // grid for headers
        private Gtk.Grid grid;
        private int column = 3;
        public delegate void workflowElement(Json.Array workflow_sequence);
        Map<string, ArrayList<Keybinding> > kbmodel;

        public WorkFlows(Array<WorkspaceDataHolder> workflowList,owned workflowElement workflow_element){
            this.set_margin_start (20);
            this.set_margin_bottom (20);
            this.set_margin_top (20);
            this.set_margin_end (20);
            this.set_orientation (Gtk.Orientation.VERTICAL);
            this.set_spacing (40);
            var headerText = new Label("Regolith Onboarding"); 
            this.add(headerText);
            grid = new Gtk.Grid();
            grid.set_row_homogeneous(true);
            grid.set_column_homogeneous(true);
            var scrolledWindow = new Gtk.ScrolledWindow(null, null);
            this.add(scrolledWindow);
            scrolledWindow.add(grid);
            scrolledWindow.set_min_content_height (350);
            scrolledWindow.set_min_content_width (800);
            grid.set_column_spacing (30);
            grid.set_row_spacing (20);
            if(workflowList.length > 4)
              column = 2;
            else if(workflowList.length <=4)
              column = 1;
            
            // fetching all the keybindings
            read_i3_config.begin((obj,res) => {
              read_i3_config.end(res);
            }); 
            foreach (var entry in kbmodel.entries) {
                var category = entry.key;
                var bindings = entry.value;

                foreach (var binding in bindings) {
                    var formatted_spec = format_spec (binding.spec);
                    var summary = category + " - " + binding.label;
                    stdout.printf("\n Formatted Spec: %s \n Summary: %s",formatted_spec,summary);
                }
            }

            // var workflowLabels = workflowList.get_keys_as_array ();
            // Create and add workflows to the grid
            int i=0;
            foreach(unowned WorkspaceDataHolder item in workflowList){
               var label = new Label(item.get_workflow_name ()); 
               var image = new Gtk.Image.from_file(item.get_workflow_image ());
               Gdk.Pixbuf pixbuf = image.get_pixbuf();
               var img = new Gtk.Image.from_pixbuf(pixbuf.scale_simple (300, 150,Gdk.InterpType.BILINEAR));
               var button = new Button();
               var gridButton = new Grid();
               button.always_show_image = true;
               button.relief = Gtk.ReliefStyle.NONE;
               img.set_hexpand (true);
               label.set_hexpand (true);
               gridButton.attach (img, 0,0,2,1);
               gridButton.attach (label, 0,1,2,1);
               button.add(gridButton);
               button.set_border_width (0);
               //button.set_image(img);
               //container.add(button);
               //container.add(label);
               button.clicked.connect (()=>{
                 workflow_element(item.get_workflow_sequence());
                 //var workflowPage = new WorkFlowPage();
               }); 
               grid.attach(button, i % column, i / column, 1, 1);
               i++;
            }
        }
        private async void read_i3_config () {
          try {
              var i3_client = new I3Client ();
              var config_file = i3_client.getConfig ().config;
              var parser = new ConfigParser (config_file, "");

              kbmodel = parser.parse ();

          } catch (GLib.Error err) {
              // TODO consistent error handling
              stderr.printf ("Failed to read config from %s: %s\n", WM_NAME, err.message);
          }
        }
        public static string format_spec (string raw_keybinding) {
            // TODO: this won't work for keybindings with < > characters
            return raw_keybinding
                    .replace ("<", "")
                    .replace (">", " ")
                    .replace ("  ", " ");
        }
    }
}
