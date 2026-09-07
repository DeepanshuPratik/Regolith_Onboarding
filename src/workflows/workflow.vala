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
         * Directory the workflow file was read from. Its images resolve against
         * this, so a workflow always carries its own artwork. null means the
         * workflow was compiled in, and resource_base applies instead.
         */
        public string? base_dir { get; set; default = null; }

        /** GResource directory used when base_dir is null. */
        public string resource_base { get; set; default = APP_PATH; }

        /** Where this came from, for log messages. */
        public string source { get; set; default = "<unknown>"; }

        public Workflow () {
            steps = new Json.Array ();
        }

        public bool is_bundled { get { return base_dir == null; } }

        /** Loads one of this workflow's images, from wherever the workflow lives. */
        public Gtk.Image load_image (string relative, int width = -1, int height = -1) {
            return AssetLoader.image (base_dir, resource_base, relative, width, height);
        }

        /**
         * As load_image, for the practice page's demo slot: fitted to a fixed
         * box so every step is the same shape, and animated if the asset is.
         */
        public Gtk.Widget load_demo (string relative, int box_w, int box_h) {
            return AssetLoader.fitted (base_dir, resource_base, relative, box_w, box_h);
        }

        /**
         * The catalogue tile's thumbnail: fitted like the demo slot, but still.
         *
         * This used to go through load_image, which scales to exactly the size
         * asked for — so a 3:2 asset in a 2:1 tile was stretched. Nothing looked
         * broken enough to report, which is the worst kind of wrong.
         */
        public Gtk.Widget load_thumbnail (string relative, int box_w, int box_h) {
            return AssetLoader.fitted (base_dir, resource_base, relative, box_w, box_h, false);
        }
    }

    /**
     * Loads workflow images from wherever the workflow itself came from: the
     * GResource bundle for built-in ones, the filesystem for anything a distro
     * package or the user dropped in.
     */
    public class AssetLoader : GLib.Object {

        public static Gdk.Pixbuf? pixbuf (string? base_dir, string resource_base,
                                          string relative,
                                          int width = -1, int height = -1) {
            if (relative.length == 0) return null;

            Gdk.Pixbuf? pb = null;
            try {
                pb = (base_dir == null)
                    ? new Gdk.Pixbuf.from_resource (resource_base + "/" + relative)
                    : new Gdk.Pixbuf.from_file (Path.build_filename (base_dir, relative));
            } catch (Error e) {
                warning ("Cannot load image '%s' (%s): %s",
                         relative, base_dir ?? resource_base, e.message);
                return null;
            }

            if (pb != null && width > 0 && height > 0)
                pb = pb.scale_simple (width, height, Gdk.InterpType.BILINEAR);
            return pb;
        }

        /** Never null, so a missing image degrades to a blank slot rather than a crash. */
        public static Gtk.Image image (string? base_dir, string resource_base,
                                       string relative,
                                       int width = -1, int height = -1) {
            var pb = pixbuf (base_dir, resource_base, relative, width, height);
            return (pb == null) ? new Gtk.Image () : new Gtk.Image.from_pixbuf (pb);
        }

        /**
         * A demo asset scaled to fit a fixed box, animating if it animates.
         *
         * Two things this fixes, both of which the user sees as one symptom —
         * the window changing size between steps:
         *
         *  - Assets are whatever size their author made them. The shipped set
         *    runs from 500x346 to 1600x900, and loading them at natural size
         *    made the practice page a different shape on every step, which the
         *    window then grew or shrank to fit.
         *  - A GIF loaded as a Pixbuf is one frame. Every animation a distro
         *    ships was being shown as a still, silently.
         *
         * The box is the caller's and is never exceeded; an asset smaller than
         * the box is left alone rather than upscaled into blur.
         */
        public static Gtk.Widget fitted (string? base_dir, string resource_base,
                                         string relative, int box_w, int box_h,
                                         bool animate = true) {
            if (relative.length == 0) return new Gtk.Image ();

            Gdk.PixbufAnimation? anim = null;
            try {
                if (base_dir == null) {
                    var stream = GLib.resources_open_stream (
                        resource_base + "/" + relative, ResourceLookupFlags.NONE);
                    anim = new Gdk.PixbufAnimation.from_stream (stream, null);
                } else {
                    anim = new Gdk.PixbufAnimation.from_file (
                        Path.build_filename (base_dir, relative));
                }
            } catch (Error e) {
                warning ("Cannot load image '%s' (%s): %s",
                         relative, base_dir ?? resource_base, e.message);
                return new Gtk.Image ();
            }

            if (anim.is_static_image ()) {
                var still = anim.get_static_image ();
                int w, h;
                fit_size (still.get_width (), still.get_height (), box_w, box_h, out w, out h);
                return new Gtk.Image.from_pixbuf (still.scale_simple (w, h, Gdk.InterpType.BILINEAR));
            }

            if (!animate) {
                // A catalogue of four tiles all playing at once is a fairground.
                // The first frame, fitted, is what a tile wants.
                var first = anim.get_static_image ();
                int fw, fh;
                fit_size (first.get_width (), first.get_height (), box_w, box_h, out fw, out fh);
                return new Gtk.Image.from_pixbuf (first.scale_simple (fw, fh, Gdk.InterpType.BILINEAR));
            }

            return new AnimatedImage (anim, box_w, box_h);
        }

        /**
         * The size an asset takes inside the box, keeping its proportions.
         *
         * Never larger than the box, and never larger than the asset: a
         * 120x80 icon stretched to fill a 340x230 slot looks worse than a
         * 120x80 icon, and the slot is a fixed size either way, so nothing
         * moves whichever way this lands.
         */
        internal static void fit_size (int src_w, int src_h, int box_w, int box_h,
                                       out int w, out int h) {
            if (src_w <= 0 || src_h <= 0) { w = box_w; h = box_h; return; }

            double scale = double.min ((double) box_w / src_w, (double) box_h / src_h);
            if (scale > 1.0) scale = 1.0;

            w = (int) Math.round (src_w * scale);
            h = (int) Math.round (src_h * scale);
            if (w < 1) w = 1;
            if (h < 1) h = 1;
        }
    }

    /**
     * A GIF that plays, scaled into the caller's box.
     *
     * GdkPixbufAnimation has no scaled form, so each frame is scaled as it is
     * shown. That is affordable for the size of asset this displays and it is
     * the only way to have both animation and a layout that does not move.
     *
     * The frame timeout is stopped when the widget goes away. A practice page is
     * destroyed on every step and rebuilt, so a timeout that outlived it would
     * accumulate one live source per step, each holding a destroyed widget.
     */
    private class AnimatedImage : Gtk.Image {

        private Gdk.PixbufAnimation anim;
        private Gdk.PixbufAnimationIter iter;
        private int box_w;
        private int box_h;
        private uint tick_id = 0;

        public AnimatedImage (Gdk.PixbufAnimation anim, int box_w, int box_h) {
            this.anim = anim;
            this.box_w = box_w;
            this.box_h = box_h;
            this.iter = anim.get_iter (null);

            show_current_frame ();
            schedule_next ();

            this.destroy.connect (() => {
                if (tick_id != 0) GLib.Source.remove (tick_id);
                tick_id = 0;
            });
        }

        private void show_current_frame () {
            var frame = iter.get_pixbuf ();
            if (frame == null) return;

            int w, h;
            AssetLoader.fit_size (frame.get_width (), frame.get_height (),
                                  box_w, box_h, out w, out h);
            set_from_pixbuf (frame.scale_simple (w, h, Gdk.InterpType.BILINEAR));
        }

        private void schedule_next () {
            var delay = iter.get_delay_time ();
            // -1 means "this frame is the last"; anything under a floor would
            // spin the main loop on a malformed file.
            if (delay < 0) return;
            if (delay < 20) delay = 20;

            tick_id = Timeout.add ((uint) delay, () => {
                tick_id = 0;
                iter.advance (null);
                show_current_frame ();
                schedule_next ();
                return Source.REMOVE;
            });
        }
    }
}
