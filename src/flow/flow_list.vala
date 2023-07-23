using Gtk;
using Gee;

namespace regolith_onboarding {
    
    public class WorkFlows : Box {
        protected Gdk.Seat seat;
        // grid for headers
        private Gtk.Grid grid;
        private Json.Array workflow_sequence;

        public WorkFlows(Array<WorkspaceDataHolder> workflowList){
            this.set_margin_start (20);
            this.set_margin_bottom (20);
            this.set_margin_top (20);
            this.set_margin_end (20);
            this.set_orientation (Gtk.Orientation.VERTICAL);
            this.set_spacing (40);
            var headerText = new Label("Regolith Onboarding"); 
            this.add(headerText);
            grid = new Gtk.Grid();
            grid.set_row_homogeneous(true);
            grid.set_column_homogeneous(true);
            var scrolledWindow = new Gtk.ScrolledWindow(null, null);
            this.add(scrolledWindow);
            scrolledWindow.add(grid);
            scrolledWindow.set_min_content_height (350);
            scrolledWindow.set_min_content_width (800);
            grid.set_column_spacing (20);
            grid.set_row_spacing (30);
            
            // var workflowLabels = workflowList.get_keys_as_array ();
            // Create and add workflows to the grid
            int i=0;
            foreach(unowned WorkspaceDataHolder item in workflowList){
               var container = new Box(Gtk.Orientation.VERTICAL, 5);
               var label = item.get_workflow_name (); 
               var image = new Gtk.Image.from_file(item.get_workflow_image ());
               Gdk.Pixbuf pixbuf = image.get_pixbuf();
               var img = new Gtk.Image.from_pixbuf(pixbuf.scale_simple (200, 100,Gdk.InterpType.BILINEAR));
               container.add(img);
               container.add(new Label(label));
               grid.attach(container, i % 3, i / 3, 1, 1);
               i++;
            }
            var workflowPage = new WorkFlowPage();
        }
    }
}
