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
     * Four layers are consulted, lowest priority first, and the results are
     * unioned so a user-installed workflow appears next to the built-in ones:
     *
     *     resource:///org/linux/Onboarding/branding/workflows/   from the branding bundle
     *     $XDG_DATA_DIRS/linux-onboarding/workflows/    distro packages
     *     $XDG_CONFIG_DIRS/linux-onboarding/workflows/  sysadmin (/etc/xdg)
     *     $XDG_CONFIG_HOME/linux-onboarding/workflows/  the user, and marketplace installs
     *
     * Only the bundled layer is flat — `workflows/01-launching.json` straight
     * under the branding directory. -DBranding_dir already commits a build to
     * one distro's identity, so the resource it compiles in never needs a
     * desktop id to disambiguate: a GNOME build's bundle is GNOME's, full stop.
     *
     * The other three are keyed by desktop environment instead, since a shortcut
     * that teaches something on sway means nothing on KDE, and unlike the
     * bundle they are not tied to any one build — the same $XDG_DATA_DIRS can
     * hold packages for several desktops, and a user's own $XDG_CONFIG_HOME
     * follows them from one desktop to another:
     *
     *     workflows/regolith/*.json
     *     workflows/gnome/*.json
     *     workflows/default/*.json
     *
     * Within one of those three, only the best-matching desktop directory is
     * read — walking Desktop.candidates in order and taking the first that
     * exists — so a layer shipping both regolith/ and default/ gets the
     * specific one, not both.
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

        /**
         * Directory a marketplace install should be copied into; shown in the
         * UI. Keyed by this session's own most specific desktop id — not a
         * bundled-resource fallthrough, since the marketplace layer is a real
         * filesystem tree that outlives any one build and is free to hold
         * more than one desktop's workflows.
         */
        public string user_install_dir () {
            return Path.build_filename (Environment.get_user_config_dir (),
                                        DATA_SUBDIR, WORKFLOWS, desktop.primary);
        }

        // Flat: the branding bundle is already this build's one desktop, so
        // there is no id left to disambiguate. See the class comment.
        private void load_bundled (Gee.ArrayList<Workflow> into) {
            var dir = "%s/%s/".printf (Branding.RESOURCE_ROOT, WORKFLOWS);

            string[] children;
            try {
                children = GLib.resources_enumerate_children (dir, ResourceLookupFlags.NONE);
            } catch (Error e) {
                return;   // this branding bundles no workflows
            }

            foreach (var child in children) {
                if (!child.has_suffix (".json")) continue;
                try {
                    var bytes = GLib.resources_lookup_data (dir + child, ResourceLookupFlags.NONE);
                    var parsed = WorkflowParser.from_data (
                        (string) bytes.get_data (), null, "bundled:" + child);
                    // Images sit beside the JSON, same as for filesystem workflows.
                    foreach (var w in parsed) w.resource_base = dir.substring (0, dir.length - 1);
                    into.add_all (parsed);
                } catch (Error e) {
                    warning ("Cannot read bundled workflow '%s': %s", child, e.message);
                }
            }
        }

        private void load_from_root (Gee.ArrayList<Workflow> into, string root) {
            if (!FileUtils.test (root, FileTest.IS_DIR)) return;

            var dir = first_existing_candidate (root, desktop.candidates);
            if (dir != null) load_dir (into, dir);
        }

        /**
         * The most specific candidate that actually has a directory under
         * root — "ubuntu" with no bundled workflows falls through to "gnome",
         * which is the whole reason the walk is a list and not just
         * `desktop.primary`. A free function so a test can drive it with a
         * fixture directory and an arbitrary candidate list, rather than
         * needing a real desktop and a real XDG layout to prove the fallthrough
         * happens at all.
         */
        internal static string? first_existing_candidate (string root, string[] candidates) {
            foreach (var id in candidates) {
                var dir = Path.build_filename (root, id);
                if (FileUtils.test (dir, FileTest.IS_DIR)) return dir;
            }
            return null;
        }

        /**
         * Everything in one desktop's directory, in both layouts.
         *
         * Flat — `gnome/01-navigation.json` — is what every existing install and
         * the bundled branding use. One folder per workflow —
         * `gnome/navigation/navigation.json` — is what the marketplace ships, so
         * that a workflow's images live beside it and two authors can both
         * ship `assets/keys.png` without colliding.
         *
         * **One level, not arbitrary depth.** This walks the user's config
         * directory; a folder they happen to have put there is not a workflow,
         * and recursing into everything would be a surprising amount of reading
         * somebody else's disk.
         *
         * Names are sorted together across both shapes, so an `NN-` prefix
         * still controls the order the catalogue lists them in whichever layout
         * a workflow arrived as.
         */
        internal void load_dir (Gee.ArrayList<Workflow> into, string dir) {
            var found = new Gee.ArrayList<string> ();   // sort keys
            var paths = new Gee.HashMap<string, string> ();

            try {
                var d = Dir.open (dir, 0);
                string? name;
                while ((name = d.read_name ()) != null) {
                    var child = Path.build_filename (dir, name);

                    if (name.has_suffix (".json")) {
                        found.add (name);
                        paths.set (name, child);
                        continue;
                    }

                    if (!FileUtils.test (child, FileTest.IS_DIR)) continue;

                    var own = workflow_in_folder (child, name);
                    if (own != null) {
                        found.add (name);
                        paths.set (name, own);
                    }
                }
            } catch (Error e) {
                warning ("Cannot list '%s': %s", dir, e.message);
                return;
            }

            found.sort ((a, b) => strcmp (a, b));

            foreach (var key in found) {
                var path = paths.get (key);
                string contents;
                try {
                    FileUtils.get_contents (path, out contents);
                } catch (Error e) {
                    warning ("Cannot read '%s': %s", path, e.message);
                    continue;
                }
                // The base directory is the one holding the JSON, so a workflow
                // in its own folder resolves `assets/x.png` against that folder
                // rather than against the desktop directory it shares with
                // everyone else.
                into.add_all (WorkflowParser.from_data (contents, Path.get_dirname (path), path));
            }
        }

        /**
         * The single JSON inside a workflow folder, or null if this is not one.
         *
         * A folder holding several JSONs is somebody's own directory rather
         * than a marketplace workflow — the marketplace allows exactly one per
         * folder — and reading all of them would be guessing.
         */
        private string? workflow_in_folder (string folder, string folder_name) {
            string? only = null;
            try {
                var d = Dir.open (folder, 0);
                string? name;
                while ((name = d.read_name ()) != null) {
                    if (!name.has_suffix (".json")) continue;
                    if (only != null) return null;          // more than one
                    only = Path.build_filename (folder, name);
                }
            } catch (Error e) {
                return null;
            }
            return only;
        }

    }
}
