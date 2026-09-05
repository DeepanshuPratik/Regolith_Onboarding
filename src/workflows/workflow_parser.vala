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
using Gee;

namespace linux_onboarding {

    /**
     * Reads workflow definition files.
     *
     * Schema:
     *
     *     {
     *       "version": 1,
     *       "desktop": "regolith",
     *       "workflows": [
     *         { "name": ..., "description": ..., "image": ...,
     *           "steps": [ { "key_id", "heading", "description", "image" } ] }
     *       ]
     *     }
     *
     * Deliberately forgiving. These files are authored by distro maintainers and
     * by whoever publishes to the marketplace, not by this project, so an
     * unrecognised key means "written against a different version" far more often
     * than it means "corrupt". Unknown members are logged and skipped; one bad
     * field never discards a whole file. The older key names are still accepted so
     * existing files keep working.
     */
    public class WorkflowParser : GLib.Object {

        public const int SUPPORTED_VERSION = 1;

        public static Gee.ArrayList<Workflow> from_data (string json,
                                                         string? base_dir,
                                                         string source) {
            var result = new Gee.ArrayList<Workflow> ();

            var parser = new Json.Parser ();
            try {
                parser.load_from_data (json);
            } catch (Error e) {
                warning ("Skipping malformed workflow file '%s': %s", source, e.message);
                return result;
            }

            var root_node = parser.get_root ();
            if (root_node == null || root_node.get_node_type () != Json.NodeType.OBJECT) {
                warning ("Skipping '%s': top level is not an object", source);
                return result;
            }

            var root = root_node.get_object ();

            if (root.has_member ("version")) {
                var v = (int) root.get_int_member ("version");
                if (v > SUPPORTED_VERSION)
                    warning ("'%s' declares version %d; this build understands %d. "
                             + "Reading what it can.", source, v, SUPPORTED_VERSION);
            }

            // "workspaces" was the pre-1 name for this array.
            Json.Array? list = null;
            if (root.has_member ("workflows"))       list = array_member (root, "workflows", source);
            else if (root.has_member ("workspaces")) list = array_member (root, "workspaces", source);

            if (list == null) {
                warning ("Skipping '%s': no \"workflows\" array", source);
                return result;
            }

            for (uint i = 0; i < list.get_length (); i++) {
                var element = list.get_element (i);
                if (element == null || element.get_node_type () != Json.NodeType.OBJECT) {
                    warning ("'%s': entry %u is not an object, skipping", source, i);
                    continue;
                }
                var workflow = parse_workflow (element.get_object (), base_dir, source);
                if (workflow != null) result.add (workflow);
            }

            return result;
        }

        private static Json.Array? array_member (Json.Object obj, string name, string source) {
            var node = obj.get_member (name);
            if (node == null || node.get_node_type () != Json.NodeType.ARRAY) {
                warning ("'%s': \"%s\" is not an array", source, name);
                return null;
            }
            return node.get_array ();
        }

        private static Workflow? parse_workflow (Json.Object obj, string? base_dir, string source) {
            var workflow = new Workflow ();
            workflow.base_dir = base_dir;
            workflow.source = source;

            foreach (unowned string member in obj.get_members ()) {
                switch (member) {
                    case "name":
                    case "workflow_name":
                        workflow.name = string_member (obj, member, source);
                        break;
                    case "description":
                    case "workflow_description":
                        workflow.description = string_member (obj, member, source);
                        break;
                    case "image":
                        workflow.image = string_member (obj, member, source);
                        break;
                    case "steps":
                    case "key_bindings_sequence":
                        var steps = array_member (obj, member, source);
                        if (steps != null) workflow.steps = steps;
                        break;
                    default:
                        warning ("'%s': ignoring unknown workflow field \"%s\"", source, member);
                        break;
                }
            }

            if (workflow.name.length == 0) {
                warning ("'%s': workflow has no name, skipping", source);
                return null;
            }
            if (workflow.steps.get_length () == 0) {
                warning ("'%s': workflow \"%s\" has no steps, skipping", source, workflow.name);
                return null;
            }
            return workflow;
        }

        private static string string_member (Json.Object obj, string name, string source) {
            var node = obj.get_member (name);
            if (node == null || node.get_node_type () != Json.NodeType.VALUE) {
                warning ("'%s': \"%s\" is not a string", source, name);
                return "";
            }
            return obj.get_string_member (name) ?? "";
        }
    }
}
