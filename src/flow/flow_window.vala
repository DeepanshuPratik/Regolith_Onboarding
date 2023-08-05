using Gtk;

namespace regolith_onboarding {
    
    public class WorkFlowPage : Box {

        public delegate void workflowList();
        private string heading = "";
        private string command = " ";
        private string description = " ";
        private uint current_key_sequence = 0;  
        private bool isPlayed = false;
        // private string keyCombination = "";
        private KeybindingsHandler keypressHandler; 
        
        public WorkFlowPage(Json.Array? key_binding_info,owned workflowList workflowList){
          
          this.set_orientation(Gtk.Orientation.VERTICAL);
          this.set_spacing(10);
          
          // setting up map
          // NOTE: need to create a new class that loads modifier table and non modifier table with signal numbers and for non modifier , we need to check for whether the values are of ASCII or not  
          
          // Adding CSS File
          var screen = this.get_screen ();
          var css_provider = new Gtk.CssProvider();
          string css_path = File.new_for_path("../src/flow/flow.css").get_path();
          if (FileUtils.test (css_path, FileTest.EXISTS)) {
            try {
              css_provider.load_from_path(css_path);
              Gtk.StyleContext.add_provider_for_screen(screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
            } catch (Error e) {
              error ("Cannot load CSS stylesheet: %s", e.message);
            }
          }else {
            stderr.printf ("file not found for css : flow_window.vala");
          }

          keypressHandler = new KeybindingsHandler();

          if(key_binding_info != null){
            var button_next = new Button();
            Json.Object obj = key_binding_info.get_element (current_key_sequence).get_object ();
            try{ 
              process_workflow_sequence (obj);
            }catch(Error e){
              stderr.printf ("Error in calling process_workflow_sequence : %s \n",e.message);
            }
            this.add (new Label(heading)); 
            this.add (new Label(command)); 
            this.add (new Label(description));
            this.add(button_next);
            stdout.printf (heading+"\n");
             
            // Route keys based on function
            key_press_event.connect ((key) => {
                stdout.printf ("\n %u %c \n", key.keyval ,(char)key.keyval);
                var configmanager = new configManager ();
                var formated_command = configmanager.format_spec(command);
                string[] splitFormatedCommands = formated_command.split(" ");
                foreach(string item in splitFormatedCommands){
                  stdout.printf (" %s ",item);
                } 
                uint COMMAND_MASK=1;
                for(int i=0;i<splitFormatedCommands.length-1;i++){
                  COMMAND_MASK = COMMAND_MASK | keypressHandler.modifierMasks[splitFormatedCommands[i]]; 
                }
                // handle upper case and lower case of a-z
                var matched = keypressHandler.match (key, COMMAND_MASK, keypressHandler.nonModifiers[splitFormatedCommands[splitFormatedCommands.length-1]]); // add uint for non modifiers which is not ascii
                //matched =  matched || keypressHandler.match (key, Gdk.ModifierType.SUPER_MASK | Gdk.ModifierType.SHIFT_MASK, KEY_CODE_RIGHT);
                stdout.printf ("MATCHED: %b", matched);
                stdout.flush ();
                return false;
            });


            button_next.clicked.connect (()=>{
              current_key_sequence++;
              if(current_key_sequence >= key_binding_info.get_length ()){
                var window = (Gtk.Window) this.get_toplevel () ;
                new HandleScreenMode(window,"WINDOW");
                workflowList();
                this.destroy();
              }
              obj = key_binding_info.get_element (current_key_sequence).get_object ();
              try{ 
                process_workflow_sequence (obj);
              }catch(Error e){
                stderr.printf ("Error in calling process_workflow_sequence : %s \n",e.message);
              }
            });
          }
          var button = new Gtk.Button();
          button.get_style_context ().add_class ("cancelButton");
          button.set_label("cancel");
          var play_button = new Button ();
          play_button.get_style_context ().add_class ("playButton");
          play_button.set_label ("PLAY");
          this.add(button);
          this.add(play_button);
          
          // turning play to capturing 
          play_button.clicked.connect(()=>{
            if(!isPlayed){
              var window = (Gtk.Window) this.get_toplevel () ;
              new HandleScreenMode(window,"TILEUP");
              isPlayed = true;
              play_button.set_label("CAPTURING");
              play_button.set_border_width (0);
            }
          });
          // to cancel the workflow in between
          button.clicked.connect(()=>{
            var window = (Gtk.Window) this.get_toplevel () ;
            new HandleScreenMode(window,"WINDOW");
            workflowList();
            this.destroy();
          });
        }
        
        public void process_workflow_sequence (Json.Object obj) throws Error {
          
          foreach (unowned string name in obj.get_members ()) {
            switch (name) {
              case "key_id":
                unowned Json.Node item = obj.get_member (name);
                if (item.get_node_type () != Json.NodeType.VALUE) {
                  throw new MyError.INVALID_FORMAT ("Unexpected element type %s process_workspaces() line 186", item.type_name ());
                }
                command = obj.get_string_member (name);
                break;

              case "function":
                unowned Json.Node item = obj.get_member (name);
                if (item.get_node_type () != Json.NodeType.VALUE) {
                  throw new MyError.INVALID_FORMAT ("Unexpected element type %s process_workspaces() line 202", item.type_name ());
                }
                description = obj.get_string_member (name);
                break;
          
              case "heading":
                unowned Json.Node item = obj.get_member (name);
                if (item.get_node_type () != Json.NodeType.VALUE) {
                  throw new MyError.INVALID_FORMAT ("Unexpected element type %s process_workspaces() line 202", item.type_name ());
                }
                heading = obj.get_string_member (name);
                break;
          
              default:
                throw new MyError.INVALID_FORMAT ("Unexpected element '%s' process_workspaces() line 217", name);
            }
          }

        }
    }
}
