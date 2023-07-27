using Gtk;

namespace regolith_onboarding {
    
    public class WorkFlowPage : Box {

        public delegate void workflowList();
        private string heading = "";
        private string command = " ";
        private string description = " ";
        private uint current_key_sequence = 0;  
        
        public WorkFlowPage(Json.Array? key_binding_info,owned workflowList workflowList){
          this.set_orientation(Gtk.Orientation.VERTICAL);
          this.set_spacing(10);
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
            button_next.clicked.connect (()=>{
              current_key_sequence++;
              if(current_key_sequence >= key_binding_info.get_length ()){
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
          button.set_label("cancel");
          this.add(button);
          button.clicked.connect(()=>{
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
