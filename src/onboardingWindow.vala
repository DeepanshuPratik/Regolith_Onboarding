// filename: src/onboardingWindow.vala

/****************************************************************************************
 * Copyright (c) 2023 Deepanshu Pratik <deepanshu.pratik@gmail.com>                     *
 *                                                                                      *
 * This program is free software; you can redistribute it and/or modify it under        *
 * the terms of the Apache License as published by the Free Software                    *
 * Foundation; either version 2 of the License, or (at your option) any later           *
 * version.                                                                             *
 *                                                                                      *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY      *
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A      *
 * PARTICULAR PURPOSE. See the Apache License for more details.                         *
 *                                                                                      *
 * You should have received a copy of the Apache License along with this program.       *
 *  If not, see <http://www.apache.org/licenses/>.                                      *
 ****************************************************************************************/
 using Gtk;

 namespace regolith_onboarding {
     
     // key press variables
     public const int KEY_CODE_ESCAPE = 65307;
     public const int KEY_CODE_CAPSLOCK = 65549;
     public const int KEY_CODE_NUMSLOCK = 65407;
     public const int KEY_CODE_LEFT_ALT = 65513;
     public const int KEY_CODE_RIGHT_ALT = 65514;
     public const int KEY_CODE_LEFT_SHIFT = 65505;
     public const int KEY_CODE_RIGHT_SHIFT = 65506;
     public const int KEY_CODE_TAB = 65289;
     public const int KEY_CODE_SUPER = 65515;
     public const int KEY_CODE_UP = 65362;
     public const int KEY_CODE_DOWN = 65364;
     public const int KEY_CODE_ENTER = 65293;
     public const int KEY_CODE_PGDOWN = 65366;
     public const int KEY_CODE_PGUP = 65365;
     public const int KEY_CODE_RIGHT = 65363;
     public const int KEY_CODE_LEFT = 65361;
     public const int KEY_CODE_SPACE = 32;
     public const int KEY_CODE_PLUS = 43;
     public const int KEY_CODE_MINUS = 45;
     public const int KEY_CODE_QUESTION = 63;
     public const int KEY_CODE_PRINTSRC = 65377;
     public const int KEY_CODE_BRIGHT_UP = 269025027;
     public const int KEY_CODE_BRIGHT_DOWN = 269025027;
     public const int KEY_CODE_MIC_MUTE = 269025202;
     public const int KEY_CODE_VOLUME_UP = 269025043;
     public const int KEY_CODE_VOLUME_DOWN = 269025041;
     public const int KEY_CODE_VOLUME_MUTE = 269025042;
     
     bool allow_scroll_wheel = false;
     // Controls access to keyboard and mouse
     protected Gdk.Seat seat;
 
     public errordomain MyError {
         INVALID_FORMAT
     }
     public class CarouselSetup : Window {
         
         // required Widgets of application
         private Gtk.Box container;
         private Hdy.Carousel carousel;
         private WorkFlowPage workflowPage;
         
         // parsing variables
         private Array<WorkspaceDataHolder> workspacesInfoHolder;
 
         public CarouselSetup (Gtk.Application app) {
             Object(application: app, type: Gtk.WindowType.POPUP);
             window_position = WindowPosition.CENTER;
 
             if (IS_SESSION_WAYLAND) {
                 set_size_request (800,450);
             } else {
                 set_default_size (800,450);
             }
               
             // Adding css file from GResource
             var css_provider = new Gtk.CssProvider();
             try {
                 css_provider.load_from_resource(APP_PATH + "/css/Regolith_Onboarding.css");
                 Gtk.StyleContext.add_provider_for_screen(this.get_screen(), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
             } catch (Error e) {
                 error ("Cannot load CSS stylesheet: %s", e.message);
             }
             this.get_style_context().add_class("carousel");
 
             // Main container setup
             container = new Box(Gtk.Orientation.VERTICAL, 30);
             container.get_style_context().add_class("main-container");
             this.add(container);
 
             carousel = new Hdy.Carousel();
             container.add(carousel);
             
             var carousel_indicator = new Hdy.CarouselIndicatorDots();
             carousel_indicator.set_carousel(carousel);
             container.add(carousel_indicator);
 
             // Load all workflow data from GResource
             load_all_workflows();
 
             // Create the list page of all workflows
             var worflowsListPage = new WorkFlows(workspacesInfoHolder, (workflow_sequence)=>{
               create_practice_page(workflow_sequence);
               this.remove(container);
               this.add(workflowPage);
               this.show_all();
             });
             
             // Create the Intro page
             var introPage = new IntroPage(()=>{
                 carousel.scroll_to_full(worflowsListPage, 800);
             });
             
             // Populate the carousel
             carousel.insert(introPage, 0);
             carousel.insert(worflowsListPage, 1);
             carousel.set_spacing(100);
             
             // Disable navigation to prevent accidental jumps during practice
             carousel.set_allow_scroll_wheel(allow_scroll_wheel);
             carousel.set_allow_mouse_drag(allow_scroll_wheel);
             carousel.set_allow_long_swipes(allow_scroll_wheel);
 
             // Connect global key press events
             key_press_event.connect ((key) => {
                 if (key.keyval == KEY_CODE_ESCAPE) {
                     quit();
                 }
                 return false;
             });
 
             // Handle platform-specific input grabbing
             if (IS_SESSION_WAYLAND) {
                 GtkLayerShell.init_for_window (this);
                 GtkLayerShell.set_layer(this, GtkLayerShell.Layer.OVERLAY);
                 GtkLayerShell.set_keyboard_mode (this, GtkLayerShell.KeyboardMode.EXCLUSIVE);
             } else {
                 // This call can be slow, so do it after the window is conceptually ready
                 var gdkwin = this.get_window ();
                 if (gdkwin != null) {
                     var grabbed_seat = grab_inputs(gdkwin);
                     if (grabbed_seat != null) {
                         set_seat(grabbed_seat);
                     } else {
                         stderr.printf ("Failed to acquire access to input devices, aborting.");
                         app.quit();
                     }
                 }
             }
         }
         
         private void load_all_workflows() {
            workspacesInfoHolder = new Array<WorkspaceDataHolder>();
            
            // --- PART 1: Load default workflows from GResource ---
            // These are now resource PATHS, not URIs.
            string[] default_workflow_paths = {
                APP_PATH + "/workflows/sampleWorkFlows.json",
                APP_PATH + "/workflows/sampleWorkFlows2.json"
            };
            
            stdout.printf("--- Loading default workflows from GResource ---\n");
            foreach (var resource_path in default_workflow_paths) {
                try {
                    // STEP 1: Look up the resource and get its raw data (bytes)
                    var bytes = GLib.resources_lookup_data(resource_path, 0);
                    
                    // STEP 2: Load that raw string data directly into the parser
                    var parser = new Json.Parser();
                    parser.load_from_data((string) bytes.get_data());
                    
                    // STEP 3: Process the parsed data
                    process(parser.get_root());
                    stdout.printf("--- Successfully processed default workflow: %s ---\n", resource_path);

                } catch(Error err){
                    stderr.printf("Critical Error: Could not load or parse default workflow '%s': %s\n", resource_path, err.message);
                }
            }
            
            // --- PART 2: Load custom user workflows from their config directory ---
            var user_config_dir = Environment.get_user_config_dir();
            var user_workflows_path = Path.build_filename(user_config_dir, "regolith-onboarding", "workflows");

            if (FileUtils.test(user_workflows_path, FileTest.IS_DIR)) {
                stdout.printf("\n--- Found user workflows directory: %s ---\n", user_workflows_path);
                try {
                    var dir = Dir.open(user_workflows_path, 0);
                    string? name;
                    while ((name = dir.read_name()) != null) {
                        if (name.has_suffix(".json")) {
                            var user_file_path = Path.build_filename(user_workflows_path, name);
                            try {
                                // This uses load_from_file because it's a real filesystem path. This is correct.
                                var parser = new Json.Parser();
                                parser.load_from_file(user_file_path);
                                process(parser.get_root());
                                stdout.printf("--- Successfully loaded user workflow: %s ---\n", name);
                            } catch (Error e) {
                                stderr.printf("Warning: Skipping malformed user workflow file '%s': %s\n", name, e.message);
                            }
                        }
                    }
                } catch (Error e) {
                    stderr.printf("Warning: Could not read user workflows from '%s': %s\n", user_workflows_path, e.message);
                }
            }
            
            stdout.printf("\n============================================\n");
            stdout.printf("Total workflows loaded (default + user): %u\n", workspacesInfoHolder.length);
            stdout.printf("============================================\n");
            stdout.flush();
        }

         public void create_practice_page(Json.Array keyBindings){
           workflowPage = new WorkFlowPage(keyBindings, ()=>{
             // Callback to return to the main list view
             this.remove(workflowPage);
             this.add(container);
             this.show_all();
           });
         }
         
         public void quit() {
             if (seat != null) seat.ungrab ();
             hide ();
             close ();
         }
         
         public void set_seat(Gdk.Seat seat) {
             regolith_onboarding.seat = seat;
         }
         
         public void process (Json.Node node) throws Error {
             if (node.get_node_type () != Json.NodeType.OBJECT) {
                 throw new MyError.INVALID_FORMAT ("Unexpected element type %s process()", node.type_name ());
             }
             unowned Json.Object obj = node.get_object ();
 
             foreach (unowned string name in obj.get_members ()) {
                 if (name == "workspaces") {
                     unowned Json.Node item = obj.get_member(name);
                     process_workspaces (item);
                 } else {
                     throw new MyError.INVALID_FORMAT ("Unexpected element '%s' process()", name);
                 }
             }
         }
         
         public void process_workspaces (Json.Node node) throws Error {
             if (node.get_node_type () != Json.NodeType.ARRAY) {
                 throw new MyError.INVALID_FORMAT ("Unexpected element '%s' process_workspaces()", node.type_name ());
             }
             unowned Json.Array objArray = node.get_array ();
             if (objArray != null) {
               for(int i=0; i<objArray.get_length(); i++){
                 Json.Object? obj = objArray.get_element(i).get_object();
                 var workspaceJson = new WorkspaceDataHolder();
                 foreach (unowned string name in obj.get_members ()) {
                   unowned Json.Node item = obj.get_member (name);
                   Json.NodeType node_type = item.get_node_type ();
                   switch (name) {
                    case "workflow_name":
                    case "workflow_description":
                      if (node_type != Json.NodeType.VALUE) throw new MyError.INVALID_FORMAT("Bad type for %s", name);
                      if (name == "workflow_name") workspaceJson.set_workflow_name(obj.get_string_member(name));
                      else workspaceJson.set_workflow_description(obj.get_string_member(name));
                      break;

                    case "image":
                      if (node_type != Json.NodeType.VALUE) throw new MyError.INVALID_FORMAT("Bad type for image");
                      workspaceJson.set_workflow_image(obj.get_string_member(name));
                      break;
                
                    case "key_bindings_sequence":
                      if (node_type != Json.NodeType.ARRAY) throw new MyError.INVALID_FORMAT("Bad type for key_bindings_sequence");
                      workspaceJson.set_workflow_sequence(obj.get_array_member(name));
                      break;
                      
                    default:
                      throw new MyError.INVALID_FORMAT ("Unexpected element '%s' in workflow object", name);
                   }
                 }
                 workspacesInfoHolder.append_val(workspaceJson);

                 // DEBUG PRINT: Print the contents of the loaded workflow object
                 stdout.printf("\n[WORKFLOW LOADED]\n");
                 stdout.printf("  Name: %s\n", workspaceJson.get_workflow_name());
                 stdout.printf("  Desc: %s\n", workspaceJson.get_workflow_description());
                 stdout.printf("  Img:  %s\n", workspaceJson.get_workflow_image());
                 stdout.printf("  Steps: %u\n", workspaceJson.get_workflow_sequence().get_length());                 
               }
             }
         }
         
         // Grabs the input devices for a given window
         private Gdk.Seat ? grab_inputs (Gdk.Window gdkwin) {
             var display = gdkwin.get_display ();
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
     }
 }