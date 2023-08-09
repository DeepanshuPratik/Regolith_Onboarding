using Gtk;
using Gee;

namespace regolith_onboarding{
  public class configManager{
    
    public Map<string, ArrayList<Keybinding> > kbmodel;
    public configManager(){

    }
    
    public async void read_i3_config () {
      try {
          var i3_client = new I3Client ();
          var config_file = i3_client.getConfig ().config;
          var parser = new ConfigParser (config_file, "");

          kbmodel = parser.parse ();
      } catch (GLib.Error err) {
          // TODO consistent error handling
          stderr.printf ("Failed to read config from %s: %s\n", WM_NAME, err.message);
      }
    }
    public  string format_spec (string raw_keybinding) {
        // TODO: this won't work for keybindings with < > characters
        return raw_keybinding
                .replace ("<", "")
                .replace (">", " ")
                .replace ("  ", " ");
    }
    public  string format_spec_display (string raw_keybinding) {
        // TODO: this won't work for keybindings with < > characters
        return raw_keybinding
                .replace ("<", " ")
                .replace (">", " ");
    }
  }  
}
