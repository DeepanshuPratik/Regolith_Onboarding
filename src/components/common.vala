using Gtk;

namespace regolith_onboarding{

  public class WorkspaceDataHolder : GLib.Object {

    private string workflow_name;
    private string workflow_description;
    private string image_url;
    private Json.Array key_bindings_sequence; 

    public WorkspaceDataHolder.with_data(string workflow_name, 
      string workflow_description,
      string image_url,
      Json.Array key_bindings_sequence){
        this.workflow_name = workflow_name;
        this.workflow_description = workflow_description;
        this.image_url = image_url;
        this.key_bindings_sequence = key_bindings_sequence;
    }
    public WorkspaceDataHolder(){
      this.workflow_name = "";
      this.workflow_description = "";
      this.image_url = "";
      this.key_bindings_sequence = new Json.Array();
    }
    public string get_workflow_name(){
      return this.workflow_name;
    }
    public string get_workflow_description(){
      return this.workflow_name;
    }
    public string get_workflow_image(){
      return this.image_url;
    }
    public Json.Array get_workflow_sequence(){
      return this.key_bindings_sequence;
    }
    public void set_workflow_name(string workflow_name){
      this.workflow_name = workflow_name;
    }
    public void set_workflow_description(string workflow_name){
      this.workflow_name = workflow_name;
    }
    public void set_workflow_image(string image_url){
      this.image_url = image_url;
    }
    public void set_workflow_sequence(Json.Array key_bindings_sequence){
      this.key_bindings_sequence = key_bindings_sequence;
    }
  }
}
