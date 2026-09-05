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

namespace linux_onboarding {

    /** One practice workflow: a titled sequence of keybinding steps. */
    public class Workflow : GLib.Object {

        public string name        { get; set; default = ""; }
        public string description { get; set; default = ""; }
        public string image       { get; set; default = ""; }
        public Json.Array steps   { get; set; }

        /**
         * Directory the workflow was read from, which its images resolve against.
         * null means it came from the compiled-in GResource bundle.
         */
        public string? base_dir { get; set; default = null; }

        /** Where this came from, for log messages. */
        public string source { get; set; default = "<unknown>"; }

        public Workflow () {
            steps = new Json.Array ();
        }

        public bool is_bundled { get { return base_dir == null; } }
    }

    /**
     * Loads workflow images from wherever the workflow itself came from: the
     * GResource bundle for built-in ones, the filesystem for anything a distro
     * package or the user dropped in.
     */
    public class AssetLoader : GLib.Object {

        public static Gdk.Pixbuf? pixbuf (string? base_dir, string relative,
                                          int width = -1, int height = -1) {
            if (relative.length == 0) return null;

            Gdk.Pixbuf? pb = null;
            try {
                pb = (base_dir == null)
                    ? new Gdk.Pixbuf.from_resource (APP_PATH + "/" + relative)
                    : new Gdk.Pixbuf.from_file (Path.build_filename (base_dir, relative));
            } catch (Error e) {
                warning ("Cannot load image '%s' (%s): %s",
                         relative, base_dir ?? "bundled", e.message);
                return null;
            }

            if (pb != null && width > 0 && height > 0)
                pb = pb.scale_simple (width, height, Gdk.InterpType.BILINEAR);
            return pb;
        }

        /** Never null, so a missing image degrades to a blank slot rather than a crash. */
        public static Gtk.Image image (string? base_dir, string relative,
                                       int width = -1, int height = -1) {
            var pb = pixbuf (base_dir, relative, width, height);
            return (pb == null) ? new Gtk.Image () : new Gtk.Image.from_pixbuf (pb);
        }
    }
}
