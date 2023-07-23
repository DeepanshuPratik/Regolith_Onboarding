using Gtk;

namespace regolith_onboarding {
    const int MAX_WINDOW_WIDTH = 1200;
    const int MAX_WINDOW_HEIGHT = 800;
    const int MIN_WINDOW_WIDTH = 200;
    const int MIN_WINDOW_HEIGHT = 100;
    bool allow_scroll_wheel = false;
    private string resource_path;
    protected Hdy.Carousel carousel;
    private uint carousel_spacing;
    
    // Controls access to keyboard and mouse
    protected Gdk.Seat seat;

    public errordomain MyError {
        INVALID_FORMAT
    }
    public class CarouselSetup : Window {
        public const int KEY_CODE_ESCAPE = 65307;
        const int MIN_WINDOW_WIDTH = 160;
        const int MIN_WINDOW_HEIGHT = 100;
        // file for resources
        private File res_file = File.new_for_path("../resources");
        // directory for JSON data
        private string directory = File.new_for_path("../workflows").get_path(); 
        private Dir dir_data;
        // Controls access to keyboard and mouse
        private Gdk.Seat seat;
        private Json.Parser parser;
        private WorkspaceDataHolder workspaceJson;
        private Array<WorkspaceDataHolder> workspacesInfoHolder;

        public CarouselSetup () {

            Object(type: Gtk.WindowType.POPUP); // Window is unmanaged
            window_position = WindowPosition.CENTER_ALWAYS;

            if (IS_SESSION_WAYLAND) {
                set_size_request (800,450);
            } else {
                set_default_size (800,450);
            }

            var container = new Box(Gtk.Orientation.VERTICAL, 30);
            this.add(container);


            var tables = new HashTable<string, string>(str_hash,str_equal);
            
            // resources loading  // sample data
            resource_path = res_file.get_path();
           // tables["Sessions"] = resource_path+"/floating.jpeg";
           // tables["Navigation"] = resource_path+"/Navigation.jpeg";
           // tables["Workspace"] = resource_path+"/workspaces.jpeg";
           // tables["Modes"] = resource_path+"/resize.jpeg";
           // tables["Ilia"] = resource_path+"/ilia.jpeg";
           // tables["Floating Windows"] = resource_path+"/floating.jpeg";
           // tables["Ili"] = resource_path+"/ilia.jpeg";
           // tables["Floating Wind"] = resource_path+"/floating.jpeg";
           // tables["Il"] = resource_path+"/ilia.jpeg";
           // tables["Floating"] = resource_path+"/floating.jpeg";
            carousel = new Hdy.Carousel();

            // adding carrousel and indicators
            container.add(carousel);
            var carousel_indicator = new Hdy.CarouselIndicatorDots();
            carousel_indicator.set_carousel(carousel);
            container.add(carousel_indicator);


            // workspace_data_holder
            var workspaceArray = new Array<string> ();
            // LOADING JSON DATA
            try{ 
                stdout.printf(directory+"\n");
                dir_data = Dir.open(directory, 0);
                while ((name = dir_data.read_name ()) != null) {
                    string path = Path.build_filename (directory, name);
                    stdout.printf(path+"\n");
                    File file = File.new_for_path(path);
                    var reader = new JsonReader(file);
                    string output = reader.output;
                    workspaceArray.append_val(output);    
                }
            }
            catch (FileError err) {
                stderr.printf ("ERR::::"+err.message);
            }
            workspacesInfoHolder = new Array<WorkspaceDataHolder>();
            foreach(string workflow in workspaceArray){
              parser = new Json.Parser ();
              parser.load_from_data(workflow);
              Json.Node root = parser.get_root();
              process(root);
            }
            // foreach(unowned WorkspaceDataHolder item in workspacesInfoHolder){
            //  stdout.printf ("\n workflow_name : %s \n",item.get_workflow_name ());
            //  stdout.printf ("\n workflow_description : %s \n",item.get_workflow_description ());
            // }
            var worflowsListPage = new WorkFlows(workspacesInfoHolder);
            var introPage = new IntroPage( ()=>{
                carousel.scroll_to_full(worflowsListPage,800);
            });
            carousel.insert(introPage, 0);
            carousel.insert(worflowsListPage,1);
            carousel_spacing = 100;
            carousel.set_spacing(carousel_spacing);

            // disabling the drags and scrolls to next page to omit jumps while training
            carousel.set_allow_scroll_wheel(allow_scroll_wheel);
            carousel.set_allow_mouse_drag(allow_scroll_wheel);
            carousel.set_allow_long_swipes(allow_scroll_wheel);


            // Route keys based on function
            key_press_event.connect ((key) => {
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
        public void process (Json.Node node) throws Error {
            if (node.get_node_type () != Json.NodeType.OBJECT) {
                throw new MyError.INVALID_FORMAT ("Unexpected element type %s process() line 158", node.type_name ());
            }
            unowned Json.Object obj = node.get_object ();

            foreach (unowned string name in obj.get_members ()) {
                switch (name) {
                case "workspaces":
                    unowned Json.Node item = obj.get_member (name);
                    // stdout.printf("\n %s : initial parse \n",item.type_name());
                    process_workspaces (item);
                    break;

                default:
                    throw new MyError.INVALID_FORMAT ("Unexpected element '%s' process() line 171 ", name);
                }
            }
        }
        public void process_workspaces (Json.Node node) throws Error {
            if (node.get_node_type () != Json.NodeType.ARRAY) {
                throw new MyError.INVALID_FORMAT ("Unexpected element '%s' process_workspaces() line 177", node.type_name ());
            }
            unowned Json.Array objArray = node.get_array ();
            if (objArray != null) {
              for(int i=0; i<objArray.get_length();i++){
                Json.Object? obj = objArray.get_element(i).get_object();
                workspaceJson = new WorkspaceDataHolder();
                foreach (unowned string name in obj.get_members ()) {
                  switch (name) {
                    case "workflow_name":
                      unowned Json.Node item = obj.get_member (name);
                      if (item.get_node_type () != Json.NodeType.VALUE) {
                        throw new MyError.INVALID_FORMAT ("Unexpected element type %s process_workspaces() line 186", item.type_name ());
                      }
                      workspaceJson.set_workflow_name(obj.get_string_member (name));
                      break;

                    case "image":
                      unowned Json.Node item = obj.get_member (name);
                      if (item.get_node_type () != Json.NodeType.VALUE) {
                        throw new MyError.INVALID_FORMAT ("Unexpected element type %s process_workspaces() line 194", item.type_name ());
                      }
                      workspaceJson.set_workflow_image(resource_path+obj.get_string_member (name));
                      break;

                    case "workflow_description":
                      unowned Json.Node item = obj.get_member (name);
                      if (item.get_node_type () != Json.NodeType.VALUE) {
                        throw new MyError.INVALID_FORMAT ("Unexpected element type %s process_workspaces() line 202", item.type_name ());
                      }
                      workspaceJson.set_workflow_description(obj.get_string_member (name));
                      break;
                
                    case "key_bindings_sequence":
                      unowned Json.Node item = obj.get_member (name);
                      // stdout.printf ("Reached here sequence ... ");
                      if (item.get_node_type () != Json.NodeType.ARRAY) {
                        throw new MyError.INVALID_FORMAT ("Unexpected element type %s process_workspaces() line 210", item.type_name ());
                      }
                      workspaceJson.set_workflow_sequence(obj.get_array_member(name));
                      // stdout.printf ("\n name : %s \n descr: %s \n image: %s \n",obj.get_string_member ("workflow_name"),obj.get_string_member ("workflow_description"),obj.get_string_member ("image"));
                      workspacesInfoHolder.append_val(workspaceJson);
                      break;

                    default:
                      throw new MyError.INVALID_FORMAT ("Unexpected element '%s' process_workspaces() line 217", name);
                  }
                }
              }
            }
        }

    }
}

