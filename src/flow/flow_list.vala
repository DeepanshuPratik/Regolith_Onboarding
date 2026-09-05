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

namespace linux_onboarding {

    public class WorkFlows : Box {
      public delegate void workflowElement(Workflow workflow);

      private const int TILE_WIDTH = 300;
      private const int TILE_HEIGHT = 150;

      public WorkFlows(Gee.List<Workflow> workflowList, owned workflowElement workflow_element){
        Object(orientation: Gtk.Orientation.VERTICAL, spacing: 20);
        this.set_margin_start(20);
        this.set_margin_bottom(20);
        this.set_margin_top(20);
        this.set_margin_end(20);

        bool can_practice = CaptureBackends.supported ();

        var headerText = new Label(can_practice ? "Select a Workflow to Practice"
                                                : "Keyboard Shortcuts");
        headerText.get_style_context().add_class("title-1");
        this.add(headerText);

        if (!can_practice) {
          var notice = new Label(CaptureBackends.unsupported_reason ());
          notice.get_style_context().add_class("notice");
          notice.wrap = true;
          notice.justify = Gtk.Justification.CENTER;
          notice.max_width_chars = 60;
          this.add(notice);
        }

        var grid = new Gtk.Grid();
        grid.set_column_spacing(20);
        grid.set_row_spacing(20);

        var scrolledWindow = new Gtk.ScrolledWindow(null, null);
        scrolledWindow.add(grid);
        scrolledWindow.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scrolledWindow.set_vexpand(true);
        this.add(scrolledWindow);

        if (workflowList.size == 0) {
          var empty = new Label("No workflows are installed for this desktop yet.");
          empty.get_style_context().add_class("notice");
          empty.wrap = true;
          empty.justify = Gtk.Justification.CENTER;
          grid.attach(empty, 0, 0, 1, 1);
          return;
        }

        int columns = (workflowList.size > 4) ? 2 : 1;

        int i = 0;
        foreach (var item in workflowList) {
           var label = new Label(item.name);
           label.get_style_context().add_class("heading");

           // Images resolve against wherever the workflow came from, so a
           // user-installed workflow can ship its own artwork.
           var thumbnail = item.load_image(item.image, TILE_WIDTH, TILE_HEIGHT);

           var button = new Button();
           button.get_style_context().add_class("workflow-button");
           button.set_tooltip_text(item.description);

           var gridButton = new Grid();
           gridButton.set_row_spacing(10);
           gridButton.attach(thumbnail, 0, 0, 1, 1);
           gridButton.attach(label, 0, 1, 1, 1);
           button.add(gridButton);

           button.clicked.connect((btn) => {
             workflow_element(item);
           });
           grid.attach(button, i % columns, i / columns, 1, 1);
           i++;
        }
    }
}
}
