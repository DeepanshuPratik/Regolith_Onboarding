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
      // stdout.printf("\n holder get function workflow_name : %s \n", this.workflow_name);
      return this.workflow_name;
    }
    public string get_workflow_description(){
      return this.workflow_description;
    }
    public string get_workflow_image(){
      return this.image_url;
    }
    public Json.Array get_workflow_sequence(){
      return this.key_bindings_sequence;
    }
    public void set_workflow_name(string workflow_name){
      this.workflow_name = workflow_name;
      // stdout.printf("\n holder set function workflow_name : %s set variable: %s \n", workflow_name,this.workflow_name);
    }
    public void set_workflow_description(string workflow_description){
      this.workflow_description = workflow_description;
      // stdout.printf("\n holder set function workflow_description : %s set variable: %s \n", this.workflow_description,this.workflow_name);
    }
    public void set_workflow_image(string image_url){
      this.image_url = image_url;
    }
    public void set_workflow_sequence(Json.Array key_bindings_sequence){
      this.key_bindings_sequence = key_bindings_sequence;
    }
  }
}
