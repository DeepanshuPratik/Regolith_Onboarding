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
     * Finds the workflows that apply to the running desktop.
     *
     * Definitions are keyed by desktop environment, since a shortcut that teaches
     * something on sway means nothing on KDE. Each source directory holds one
     * subdirectory per desktop id:
     *
     *     workflows/regolith/*.json
     *     workflows/gnome/*.json
     *     workflows/default/*.json
     *
     * Four layers are consulted, lowest priority first, and the results are
     * unioned so a user-installed workflow appears next to the built-in ones:
     *
     *     resource:///org/linux/Onboarding/branding/workflows/   from the branding bundle
     *     $XDG_DATA_DIRS/linux-onboarding/workflows/    distro packages
     *     $XDG_CONFIG_DIRS/linux-onboarding/workflows/  sysadmin (/etc/xdg)
     *     $XDG_CONFIG_HOME/linux-onboarding/workflows/  the user, and marketplace installs
     *
     * Within a layer only the best-matching desktop directory is read — walking
     * Desktop.candidates in order and taking the first that exists — so a distro
     * shipping both regolith/ and default/ gets the specific one, not both.
     */
    public class WorkflowLocator : GLib.Object {

        private const string WORKFLOWS = "workflows";

        private Desktop desktop = Desktop.get_default ();

        public Gee.ArrayList<Workflow> load () {
            var all = new Gee.ArrayList<Workflow> ();

            load_bundled (all);
            foreach (var dir in Environment.get_system_data_dirs ())
                load_from_root (all, Path.build_filename (dir, DATA_SUBDIR, WORKFLOWS));
            foreach (var dir in Environment.get_system_config_dirs ())
                load_from_root (all, Path.build_filename (dir, DATA_SUBDIR, WORKFLOWS));
            load_from_root (all, Path.build_filename (
                Environment.get_user_config_dir (), DATA_SUBDIR, WORKFLOWS));

            message ("loaded %d workflow(s) for desktop '%s'", all.size, desktop.primary);
            return all;
        }

        /** Directory a marketplace install should be copied into; shown in the UI. */
        public string user_install_dir () {
            return Path.build_filename (Environment.get_user_config_dir (),
                                        DATA_SUBDIR, WORKFLOWS, chosen_bundled_id ());
        }

        private void load_bundled (Gee.ArrayList<Workflow> into) {
            var id = chosen_bundled_id ();
            var dir = "%s/%s/%s/".printf (Branding.RESOURCE_ROOT, WORKFLOWS, id);

            string[] children;
            try {
                children = GLib.resources_enumerate_children (dir, ResourceLookupFlags.NONE);
            } catch (Error e) {
                return;   // nothing bundled for this desktop
            }

            foreach (var child in children) {
                if (!child.has_suffix (".json")) continue;
                try {
                    var bytes = GLib.resources_lookup_data (dir + child, ResourceLookupFlags.NONE);
                    var parsed = WorkflowParser.from_data (
                        (string) bytes.get_data (), null, "bundled:" + id + "/" + child);
                    // Images sit beside the JSON, same as for filesystem workflows.
                    foreach (var w in parsed) w.resource_base = dir.substring (0, dir.length - 1);
                    into.add_all (parsed);
                } catch (Error e) {
                    warning ("Cannot read bundled workflow '%s': %s", child, e.message);
                }
            }
        }

        // Which bundled desktop directory to use — first candidate that exists.
        private string chosen_bundled_id () {
            foreach (var id in desktop.candidates) {
                var probe = "%s/%s/%s/".printf (Branding.RESOURCE_ROOT, WORKFLOWS, id);
                try {
                    var children = GLib.resources_enumerate_children (probe, ResourceLookupFlags.NONE);
                    if (children.length > 0) return id;
                } catch (Error e) {
                    continue;
                }
            }
            return Desktop.FALLBACK_ID;
        }

        private void load_from_root (Gee.ArrayList<Workflow> into, string root) {
            if (!FileUtils.test (root, FileTest.IS_DIR)) return;

            foreach (var id in desktop.candidates) {
                var dir = Path.build_filename (root, id);
                if (!FileUtils.test (dir, FileTest.IS_DIR)) continue;
                load_dir (into, dir);
                return;   // most specific match for this layer wins
            }
        }

        private void load_dir (Gee.ArrayList<Workflow> into, string dir) {
            try {
                var d = Dir.open (dir, 0);
                string? name;
                var names = new Gee.ArrayList<string> ();
                while ((name = d.read_name ()) != null)
                    if (name.has_suffix (".json")) names.add (name);

                // Stable order so a NN- prefix can be used to control listing order.
                names.sort ((a, b) => strcmp (a, b));

                foreach (var n in names) {
                    var path = Path.build_filename (dir, n);
                    string contents;
                    try {
                        FileUtils.get_contents (path, out contents);
                    } catch (Error e) {
                        warning ("Cannot read '%s': %s", path, e.message);
                        continue;
                    }
                    into.add_all (WorkflowParser.from_data (contents, dir, path));
                }
            } catch (Error e) {
                warning ("Cannot list '%s': %s", dir, e.message);
            }
        }
    }
}
