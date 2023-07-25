using Gtk;

namespace regolith_onboarding {
    
    public class WorkFlowPage : Box {

        public delegate void workflowList();
        
        public WorkFlowPage(Json.Array? key_binding_info,owned workflowList workflowList){
          this.set_orientation(Gtk.Orientation.VERTICAL);
          this.set_spacing(10);
          if(key_binding_info!=null && key_binding_info.get_length () > 0){
             stdout.printf("Reached here : number of keybindings: %u \n",key_binding_info.get_length ());
          }
          this.add( new Label("TRY to cancel"));
          this.add(new Gtk.Image.from_file("/home/deepanshupratik/GSOC_2023/Regolith_Onboarding/resources/Navigation.jpeg"));          
          var button = new Gtk.Button();
          button.set_label("cancel");
          this.add(button);
          stdout.printf("Button label set %s \n",button.get_label());
          button.clicked.connect(()=>{
            stdout.printf("Button triggered \n");
            workflowList();
            this.destroy();
          });
        }
    }
}
