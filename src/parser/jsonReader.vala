using Gtk;

namespace regolith_onboarding{
    public class JsonReader{
        public string output;
        public JsonReader(File file){
            try {
                FileInputStream @is = file.read ();
                DataInputStream dis = new DataInputStream (@is);
                string line;
                output = "";
                while ((line = dis.read_line ()) != null) {
                    output+=line+"\n";
                }
            } catch (Error e) {
                print ("Error: %s\n", e.message);
            }
        }
    }
}