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

    /**
     * The distro's identity: name, tagline, logo, theme and featured slides.
     *
     * Unlike workflows, branding is compiled into the binary rather than read
     * from disk. A distro owner points the build at their own branding directory
     * and ships the result, so a build's identity is fixed and cannot be missing
     * or altered at runtime:
     *
     *     meson setup build -Dbranding_dir=/path/to/their-branding
     *
     * The directory holds branding.conf (this file's schema), a logo, a theme.css
     * layered over the app's own stylesheet, and slides/*.html.
     */
    public class Branding : GLib.Object {

        public const string RESOURCE_ROOT = APP_PATH + "/branding";

        private static Branding? instance = null;

        public string name             { get; private set; default = "Linux"; }
        public string tagline          { get; private set; default = ""; }
        public string logo_resource    { get; private set; default = ""; }
        public string theme_resource   { get; private set; default = ""; }
        public bool   allow_slide_scripts { get; private set; default = false; }
        public string marketplace_name { get; private set; default = ""; }
        public string marketplace_url  { get; private set; default = ""; }

        /** Slide resource paths, in presentation order. May be empty. */
        public string[] slides { get; private set; }

        public static Branding get_default () {
            if (instance == null) instance = new Branding ();
            return instance;
        }

        private Branding () {
            slides = {};

            var keyfile = new KeyFile ();
            try {
                var bytes = GLib.resources_lookup_data (
                    RESOURCE_ROOT + "/branding.conf", ResourceLookupFlags.NONE);
                keyfile.load_from_data ((string) bytes.get_data (), bytes.get_size (),
                                        KeyFileFlags.NONE);
            } catch (Error e) {
                warning ("No usable branding.conf compiled in (%s); using defaults.", e.message);
                return;
            }

            name    = read (keyfile, "Branding", "Name", name);
            tagline = read (keyfile, "Branding", "Tagline", tagline);

            var logo = read (keyfile, "Branding", "Logo", "");
            if (logo != "") logo_resource = RESOURCE_ROOT + "/" + logo;

            var theme = read (keyfile, "Branding", "Theme", "");
            if (theme != "") theme_resource = RESOURCE_ROOT + "/" + theme;

            allow_slide_scripts = read (keyfile, "Branding", "AllowSlideScripts", "false").down () == "true";

            marketplace_name = read (keyfile, "Marketplace", "Name", "");
            marketplace_url  = read (keyfile, "Marketplace", "Url", "");

            slides = resolve_slides (read (keyfile, "Branding", "SlideOrder", ""));

            message ("branding: %s, %d slide(s)%s", name, slides.length,
                     allow_slide_scripts ? ", scripts enabled" : "");
        }

        private static string read (KeyFile kf, string group, string key, string fallback) {
            try {
                if (kf.has_group (group) && kf.has_key (group, key))
                    return kf.get_string (group, key).strip ();
            } catch (Error e) {
                warning ("branding.conf: cannot read %s/%s: %s", group, key, e.message);
            }
            return fallback;
        }

        /**
         * SlideOrder wins when present, so a distro can control sequence and omit
         * work-in-progress files. Otherwise every .html in slides/ is shown in
         * filename order, which is why the shipped ones carry NN- prefixes.
         */
        private string[] resolve_slides (string order) {
            string[] result = {};
            var dir = RESOURCE_ROOT + "/slides/";

            if (order != "") {
                foreach (var entry in order.split (";")) {
                    var name = entry.strip ();
                    if (name.length == 0) continue;
                    var path = dir + name;
                    if (resource_exists (path)) result += path;
                    else warning ("branding.conf: SlideOrder lists '%s', which is not bundled", name);
                }
                return result;
            }

            string[] children;
            try {
                children = GLib.resources_enumerate_children (dir, ResourceLookupFlags.NONE);
            } catch (Error e) {
                return result;   // no slides/ directory at all
            }

            var names = new Gee.ArrayList<string> ();
            foreach (var child in children)
                if (child.has_suffix (".html")) names.add (child);
            names.sort ((a, b) => strcmp (a, b));

            foreach (var n in names) result += dir + n;
            return result;
        }

        private static bool resource_exists (string path) {
            try {
                GLib.resources_get_info (path, ResourceLookupFlags.NONE, null, null);
                return true;
            } catch (Error e) {
                return false;
            }
        }

        /** Applies the distro theme over the app's base stylesheet. */
        public void apply_theme (Gdk.Screen screen) {
            if (theme_resource == "") return;
            var provider = new Gtk.CssProvider ();
            provider.load_from_resource (theme_resource);
            // USER+1 so the distro sheet beats the app's own USER-priority ones.
            Gtk.StyleContext.add_provider_for_screen (
                screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_USER + 1);
        }
    }
}
