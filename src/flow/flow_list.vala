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
using Gee;

namespace regolith_onboarding {
    
    public class WorkFlows : Box {
      public delegate void workflowElement(Json.Array workflow_sequence);

      public WorkFlows(Array<WorkspaceDataHolder> workflowList, owned workflowElement workflow_element){
        Object(orientation: Gtk.Orientation.VERTICAL, spacing: 20);
        this.set_margin_start(20);
        this.set_margin_bottom(20);
        this.set_margin_top(20);
        this.set_margin_end(20);
        
        var headerText = new Label("Select a Workflow to Practice"); 
        headerText.get_style_context().add_class("title-1"); // Use a standard title style
        this.add(headerText);
        
        var grid = new Gtk.Grid();
        grid.set_column_spacing(20);
        grid.set_row_spacing(20);

        var scrolledWindow = new Gtk.ScrolledWindow(null, null);
        scrolledWindow.add(grid);
        scrolledWindow.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC); // Hide horizontal scrollbar
        scrolledWindow.set_vexpand(true);

        this.add(scrolledWindow);

        
        int column = (workflowList.length > 4) ? 2 : 1;
        
        int i = 0;
        foreach(unowned WorkspaceDataHolder item in workflowList){
           var label = new Label(item.get_workflow_name()); 
           string image_path = item.get_workflow_image(); // returns "images/Navigation.jpeg" etc.
           
           var image = new Gtk.Image.from_resource(APP_PATH + "/" + image_path);
           Gdk.Pixbuf pixbuf = image.get_pixbuf();
           var scaled_img = new Gtk.Image.from_pixbuf(pixbuf.scale_simple(300, 150, Gdk.InterpType.BILINEAR));
           
           var button = new Button();
           button.get_style_context().add_class("workflow-button"); // Use CSS for styling

           var gridButton = new Grid();
           gridButton.set_row_spacing(10);
           gridButton.attach(scaled_img, 0, 0, 1, 1);
           gridButton.attach(label, 0, 1, 1, 1);
           button.add(gridButton);
           
           button.clicked.connect((btn) => {
             workflow_element(item.get_workflow_sequence());
           }); 
           grid.attach(button, i % column, i / column, 1, 1);
           i++;
        }
    }
}
}