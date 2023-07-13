using Gtk;
using Gee;

namespace regolith_onboarding {
    
    public class WorkFlows : Window {
        
        public WorkFlows(HashTable<Label,Image> workflowList){

            Object(type: Gtk.WindowType.POPUP);
            window_position = WindowPosition.CENTER_ALWAYS;
            var grid = new Gtk.Grid();
            grid.set_row_homogeneous(true);
            grid.set_column_homogeneous(true);
            this.add(grid);
        
            var workflowLabels = workflowList.get_keys_as_array ();
            // Create and add labels to the grid
            for (int i = 0; i < workflowLabels.length; i++) {  
                var label = workflowLabels[i];
                grid.attach(workflowList[label], i % 3, i / 3, 1, 1);
            }

        }
    }
}