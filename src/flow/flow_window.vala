using Gtk;

namespace regolith_onboarding {
    
    public class WorkFlowPage : Box {

        public delegate void workflowList();
        
        public WorkFlowPage(Json.Array key_binding_info,owned workflowList workflowList){
          var container = new Box(Gtk.Orientation.VERTICAL, 5);  
          
          if(key_binding_info.get_length () > 0){
             stdout.printf("%u",key_binding_info.get_length ());
          }
          this.add(container);
          container.add( new Label("TRY to cancel"));
          container.add(new Gtk.Image.from_file("/home/deepanshupratik/GSOC_2023/Regolith_Onboarding/resources/Navigation.jpeg"));          
          var button = new Gtk.Button();
          button.set_label("cancel");
          container.add(button);
          button.clicked.connect(()=>{
            workflowList();
            this.destroy();
          });
        }
    }
}
