using Gee;
using Json;
using GLib;

void searchCommands(string jsonFile, string targetFile) {
    var jsonParser = new Json.Parser();
    try {
        string jsonFileContents = FileUtil.get_contents(jsonFile);
        Json.Node? rootNode = jsonParser.load_from_data(jsonFileContents, -1);

        if (rootNode != null && rootNode.get_node_type() == Json.NodeType.ARRAY) {
            Json.Array commandArray = (Json.Array)rootNode;
            var result = new HashMap<string, HashMap<string, string>>();

            try {
                string targetFileContents = FileUtil.get_contents(targetFile);

                foreach (var value in commandArray) {
                    if (value.get_node_type() == Json.NodeType.OBJECT) {
                        Json.Object commandObject = (Json.Object)value;
                        string commandId = commandObject.get_string_member("command_id");
                        string pattern = @"## " + commandId + @" ##\n(.*?)\n\n";

                        Regex regex = new Regex(pattern);
                        MatchInfo match = regex.match(targetFileContents);

                        if (match.matches()) {
                            string commandText = match.fetch(1);
                            var commandData = new HashMap<string, string>();
                            commandData["command_text"] = commandText;
                            commandData["commands"] = commandObject.get_string_member("commands");
                            result[commandId] = commandData;
                        }
                    }
                }

                Json.Node? jsonResult = Json.Builder.create().add_value(result).get_root();
                if (jsonResult != null) {
                    stdout.printf("%s\n", jsonResult.to_string());
                }
            } catch (Error e) {
                stderr.printf("Error: %s\n", e.message);
            }
        }
    } catch (Error e) {
        stderr.printf("Error: %s\n", e.message);
    }
}
