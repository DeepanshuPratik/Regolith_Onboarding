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
    
    public class WorkFlowPage : Box {

        public delegate void workflowList();
        // variables for holding json data to be displayed
        private string heading = "";
        private string command = "";
        private string description = "";
        private string animation = "";
        private string execCommand = "";

        // window positions storing variables
        private int curr_x = 0;
        private int curr_y = 0;

        // Json iterator 
        private uint current_key_sequence = 0;
        // to update it for size of window
        private bool isPlayed = false;
        private KeybindingsHandler keypressHandler;
        private Gtk.Image demo;
        private Gtk.Box demo_box;
        private Gtk.Button play_button;
        private Gtk.Button cancel_button;
        private Gtk.Box checkedCommand;
        private Gtk.Image checkTicked;
        private string mode = "";
        
        // UI components
        private Gtk.Box midBox; 
        private Gtk.Box instructionAndPlayHolder;
        private Label headingLabel;
        private Label commandLabel;
        private Label descriptionLabel;
        
        public WorkFlowPage(Json.Array? key_binding_info,owned workflowList workflowList){
          Object(orientation: Gtk.Orientation.VERTICAL, spacing: 10);
          this.margin = 20;
          this.set_valign(Gtk.Align.CENTER);
          this.set_halign(Gtk.Align.CENTER);
          this.get_style_context().add_class("practice-page");

          var css_provider = new Gtk.CssProvider();
          css_provider.load_from_resource(APP_PATH + "/css/flow.css");
          Gtk.StyleContext.add_provider_for_screen(this.get_screen(), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);

          // @widget buttonHolder will have the buttons: @widget play_button and @widget cancel_button
          var buttonHolder = new Box(Gtk.Orientation.HORIZONTAL,2);
          keypressHandler = new KeybindingsHandler();
          // config manager will provide functions to reformat the commands extracted
          var configmanager = new configManager ();
          if(key_binding_info != null){
            Json.Object obj = key_binding_info.get_element (current_key_sequence).get_object ();
            try{ 
              process_workflow_sequence (obj);
            }catch(Error e){
              stderr.printf ("Error in calling process_workflow_sequence : %s \n",e.message);
            }

            // setting up display components 
            headingLabel = new Label (heading);
            commandLabel = new Label ("PRESS: "+configmanager.format_spec_display (command));

            headingLabel.get_style_context().add_class("heading");
            descriptionLabel = new Label (description);
            instructionAndPlayHolder = new Gtk.Box(Gtk.Orientation.VERTICAL,10);
            instructionAndPlayHolder.set_valign(Gtk.Align.CENTER);
            createInstructionBox();
            midBox = new Box(Gtk.Orientation.HORIZONTAL,20);
            midBox.get_style_context().add_class("contentHolder");
            string image_path_from_json = animation; // 'animation' is populated by process_workflow_sequence

            demo = new Gtk.Image.from_resource(APP_PATH + "/images" + image_path_from_json);
            demo_box = new Gtk.Box(Gtk.Orientation.VERTICAL,5);
            demo_box.add(demo);
            
            midBox.add(instructionAndPlayHolder);
            midBox.add(demo_box);
            this.add (midBox); 
            
            cancel_button = new Gtk.Button();
            cancel_button.get_style_context ().add_class ("cancelButton");
            cancel_button.set_label("CANCEL");
            
            play_button = new Button ();
            play_button.get_style_context ().add_class ("playButton");
            play_button.set_label ("PLAY");
            
            buttonHolder.add(play_button);
            buttonHolder.add(cancel_button);
            buttonHolder.expand = false;
            buttonHolder.set_halign(Gtk.Align.CENTER); 
            
            instructionAndPlayHolder.add(buttonHolder);
            

            //  key_press_event.connect((key) => handle_key_press(key, key_binding_info));

            // Route keys based on function
            key_press_event.connect ((key) => {
                // stdout.printf ("\n KEY PRESSED:%u %c \n", key.keyval ,(char)key.keyval);
                if (!isPlayed) return false;
                if(mode != "TILEUP")
                  return false;
                
                var formated_command = configmanager.format_spec(command);
                stdout.printf ("\n FORMATED COMMAND: %s \n", formated_command);
                string[] splitFormatedCommands = formated_command.split(" ");
                uint COMMAND_MASK = 0;
                uint command_size = splitFormatedCommands.length;
                stdout.printf ("command size: %u \n", command_size);

                for(int i=0; i<splitFormatedCommands.length-1; i++){
                  //  stdout.printf ("reached modifier %u ",keypressHandler.modifierMasks[splitFormatedCommands[i]]);
                  COMMAND_MASK = COMMAND_MASK | keypressHandler.modifierMasks[splitFormatedCommands[i]];
                }
                
                bool matched = false;
                if(keypressHandler.nonModifiers.get(splitFormatedCommands[command_size-1]) != (uint)null){
                  stdout.printf ("reached non mods %u ",keypressHandler.nonModifiers[splitFormatedCommands[command_size-1]]);
                  matched = keypressHandler.match (key, COMMAND_MASK, keypressHandler.nonModifiers[splitFormatedCommands[command_size-1]],true);
                }
                else{
                  //  stdout.printf ("reached else %u ",(uint)splitFormatedCommands[command_size-1][0]);
                  matched = keypressHandler.match (key, COMMAND_MASK, (uint)splitFormatedCommands[command_size-1][0],false); 
                }
                stdout.printf ("MATCHED: %b", matched);
                if(matched){
                  COMMAND_MASK = 0;
                  current_key_sequence++;

                  // Handeling the tick and moving forward to next key binding
                  regolith_onboarding.seat.ungrab(); 
                  stdout.printf("\n **** reached before %s\n",execCommand);
                  Posix.system(execCommand);
                  
                  stdout.printf("\n **** reached after %s\n",execCommand);
                  handleTick();
                  Gdk.Window gdkwin = this.get_window ();
                  regolith_onboarding.seat.grab(gdkwin, Gdk.SeatCapabilities.KEYBOARD | Gdk.SeatCapabilities.POINTER, true, null, null, null);
                  this.show_all();
                  GLib.Timeout.add_seconds(2,()=>{
                    var window = (Gtk.Window) this.get_toplevel () ;    
                    new HandleScreenMode(window,"WINDOW",curr_x,curr_y);
                    mode = "WINDOW";
                    if(current_key_sequence >= key_binding_info.get_length ()){
                      workflowList();
                      this.destroy();
                    }
                    obj = key_binding_info.get_element (current_key_sequence).get_object ();
                    try{ 
                      process_workflow_sequence (obj);
                      this.margin = 20;
                      play_button.margin_end = 5;
                      cancel_button.margin = 0;
                      midBox.set_spacing(20);
                      midBox.margin = 3;
                      instructionAndPlayHolder.remove(headingLabel);
                      instructionAndPlayHolder.remove(commandLabel);
                      instructionAndPlayHolder.remove(checkedCommand);
                      headingLabel = new Label(heading);
                      headingLabel.get_style_context().add_class("heading");
                      commandLabel = new Label("PRESS: "+configmanager.format_spec_display (command));
                      descriptionLabel = new Label(description);
                      createInstructionBox();
                      image_path_from_json = animation; 
                      demo = new Gtk.Image.from_resource(APP_PATH + "/" + image_path_from_json);
                      demo_box.add (demo);
                      play_button.get_style_context ().add_class ("playButton");
                      play_button.set_label("PLAY");
                      isPlayed = false; 
                      stderr.printf ("isPlayed %b", isPlayed);
                      instructionAndPlayHolder.reorder_child(buttonHolder,3); 
                      this.show_all ();
                    }catch(Error e){
                      stderr.printf ("Error in calling process_workflow_sequence : %s \n",e.message);
                    }
                    return false;
                  });
                  return true;
                }
                stdout.flush ();
                return false;
            });
            
            // turning play to capturing 
            play_button.clicked.connect(()=>{
              if(!isPlayed){
                var window = (Gtk.Window) this.get_toplevel () ;
                if(curr_x == 0 && curr_y == 0)
                  window.get_position(out curr_x, out curr_y);
                new HandleScreenMode(window,"TILEUP",curr_x,curr_y);
                mode = "TILEUP";
                instructionAndPlayHolder.remove(descriptionLabel);
                checkedCommand.add(checkTicked);
                checkTicked.opacity = 0;
                instructionAndPlayHolder.margin = 0;
                this.margin = 20;
                play_button.margin = 0;
                cancel_button.margin = 0;
                midBox.set_spacing(0);
                midBox.margin = 0;
                this.expand = false;
                this.set_halign(Gtk.Align.CENTER); 
                demo_box.remove (demo);
                isPlayed = true;
                buildExecCommandString();
                play_button.set_label("CAPTURING");
                this.show_all();
              }
            });
            // to cancel the workflow in between
            cancel_button.clicked.connect(()=>{
              var window = (Gtk.Window) this.get_toplevel () ;
              if(curr_x == 0 && curr_y == 0)
                window.get_position(out curr_x, out curr_y);
              new HandleScreenMode(window,"WINDOW",curr_x,curr_y);
              mode = "WINDOW";
              workflowList();
              this.destroy();
            });
          }
        }
        
        public void process_workflow_sequence (Json.Object learnModule) throws Error {
          
          foreach (unowned string name in learnModule.get_members ()) {
            switch (name) {
              case "key_id":
                unowned Json.Node item = learnModule.get_member (name);
                if (item.get_node_type () != Json.NodeType.VALUE) {
                  throw new MyError.INVALID_FORMAT ("Unexpected element type %s process_workspaces() line 186", item.type_name ());
                }
                command = learnModule.get_string_member (name);
                break;

              case "description":
                unowned Json.Node item = learnModule.get_member (name);
                if (item.get_node_type () != Json.NodeType.VALUE) {
                  throw new MyError.INVALID_FORMAT ("Unexpected element type %s process_workspaces() line 202", item.type_name ());
                }
                description = learnModule.get_string_member (name);
                break;
          
              case "heading":
                unowned Json.Node item = learnModule.get_member (name);
                if (item.get_node_type () != Json.NodeType.VALUE) {
                  throw new MyError.INVALID_FORMAT ("Unexpected element type %s process_workspaces() line 202", item.type_name ());
                }
                heading = learnModule.get_string_member (name);
                break;

              case "animation":
                unowned Json.Node item = learnModule.get_member (name);
                if (item.get_node_type () != Json.NodeType.VALUE) {
                  throw new MyError.INVALID_FORMAT ("Unexpected element type %s process_workspaces() line 202", item.type_name ());
                }
                animation = learnModule.get_string_member (name);
                break;
          
              default:
                throw new MyError.INVALID_FORMAT ("Unexpected element '%s' process_workspaces() line 217", name);
            }
          }

        }
        public void createInstructionBox(){
          instructionAndPlayHolder.get_style_context().add_class("commandDetailHolder"); 
          instructionAndPlayHolder.add(headingLabel);
          instructionAndPlayHolder.add(descriptionLabel);
          checkedCommand = new Box(Gtk.Orientation.HORIZONTAL, 20);
          checkTicked = new Gtk.Image.from_resource(APP_PATH + "/images/checktick.gif");
          checkedCommand.add(commandLabel);
          instructionAndPlayHolder.add(checkedCommand);
          checkedCommand.set_halign(Gtk.Align.CENTER);
        }

        public void handleTick(){
          checkTicked.opacity = 1.0; 
        }
        
        public void buildExecCommandString(){
            var configmanager = new configManager ();
            execCommand = "xdotool sleep 0.5 key --clearmodifiers ";
            string[] splitCommands = configmanager.format_spec(command).split(" "); 
            for(int i=0; i<splitCommands.length-1; i++){
              execCommand += keypressHandler.remontoireSymToKey[splitCommands[i]] + "+";
            }
            if(keypressHandler.remontoireSymToKey.get(splitCommands[splitCommands.length-1]) != (string)null){
              execCommand += keypressHandler.remontoireSymToKey[splitCommands[splitCommands.length-1]];
            }
            else{
              execCommand += splitCommands[splitCommands.length-1];
            }
            stdout.printf("execute command : %s \n", execCommand);
        }
    }
}
