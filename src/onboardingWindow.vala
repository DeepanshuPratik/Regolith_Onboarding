using Gtk;

namespace regolith_onboarding {
    const int MAX_WINDOW_WIDTH = 1200;
    const int MAX_WINDOW_HEIGHT = 800;
    const int MIN_WINDOW_WIDTH = 200;
    const int MIN_WINDOW_HEIGHT = 100;
    bool allow_scroll_wheel = false;
    private string resource_path;
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
        // directory for JSON data
        private string directory = File.new_for_path("../workflows").get_path(); 
        private Dir dir_data;
        // required Widgets of application
        private Gtk.Box container;
        private Hdy.Carousel carousel;
        private Hdy.CarouselIndicatorDots carousel_indicator; 
        private WorkFlowPage workflowPage;
        private GLib.Object prev_child;
        private GLib.Object cur_child;
        // Controls access to keyboard and mouse
        private Gdk.Seat seat;
        // parsing variables
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
              
            
            // initializing file path for resources
            resource_path = File.new_for_path("../resources").get_path();
            container = new Box(Gtk.Orientation.VERTICAL, 30);
            this.add(container);

            carousel = new Hdy.Carousel();

            // adding carrousel and indicators
            container.add(carousel);
            carousel_indicator = new Hdy.CarouselIndicatorDots();
            carousel_indicator.set_carousel(carousel);
            container.add(carousel_indicator);

            // workspace_data_holder
            var workspaceArray = new Array<string> ();
            // LOADING JSON DATA of multiple files as Array of string where each string represent each file data
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
            try {
              foreach(string workflow in workspaceArray){
                parser = new Json.Parser();
                parser.load_from_data(workflow);
                Json.Node root = parser.get_root();
                process(root);
              }
            }catch(Error err){
              stderr.printf("Array of string is null ERR: %s ",err.message);
            }
            var worflowsListPage = new WorkFlows(workspacesInfoHolder, (workflow_sequence)=>{
              create_practice_page(workflow_sequence); 
              cur_child = workflowPage.ref();
              prev_child = container.ref();
              this.remove(container);
              this.add(workflowPage);
              this.show_all();
            });
            workflowPage = new WorkFlowPage(null,()=>{});
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
                    container.set_opacity(0.6);
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
        public void create_practice_page(Json.Array keyBindings){
          workflowPage = new WorkFlowPage(keyBindings, ()=>{
            // remove itself from container and add carousel
            cur_child = container.ref();
            prev_child = workflowPage.ref();
            this.remove(workflowPage);
            this.add(container);
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
                      if (item.get_node_type () != Json.NodeType.ARRAY) {
                        throw new MyError.INVALID_FORMAT ("Unexpected element type %s process_workspaces() line 210", item.type_name ());
                      }
                      workspaceJson.set_workflow_sequence(obj.get_array_member(name));
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

