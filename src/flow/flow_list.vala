using Gtk;
using Gee;

namespace regolith_onboarding {
    
    public class WorkFlows : Box {
        protected Gdk.Seat seat;
        // grid for headers
        private Gtk.Grid grid;
        private Json.Array workflow_sequence;

        public WorkFlows(HashTable<string,string> workflowList){
            this.set_margin_top (20);
            this.set_orientation (Gtk.Orientation.VERTICAL);
            this.set_spacing (40);
            var headerText = new Label("Regolith Onboarding"); 
            this.add(headerText);
            grid = new Gtk.Grid();
            grid.set_row_homogeneous(true);
            grid.set_column_homogeneous(true);
            var scrolledWindow = new Gtk.ScrolledWindow(null, null);
            scrolledWindow.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
            //this.add(scrolledWindow);
            this.add(grid);
            grid.set_column_spacing (48);
            grid.set_row_spacing (10);
            
            var workflowLabels = workflowList.get_keys_as_array ();
            // Create and add workflows to the grid
            for (int i = 0; i < workflowLabels.length; i++) {  
                var container = new Box(Gtk.Orientation.VERTICAL, 5);
                var label = workflowLabels[i];
                var image = new Gtk.Image.from_file(workflowList[label]);
                Gdk.Pixbuf pixbuf = image.get_pixbuf();
                var img = new Gtk.Image.from_pixbuf(pixbuf.scale_simple (200, 100,Gdk.InterpType.BILINEAR));
                container.add(img);
                container.add(new Label(label));
                grid.attach(container, i % 3, i / 3, 1, 1);
            }
            var workflowPage = new WorkFlowPage();
        }
    }
}