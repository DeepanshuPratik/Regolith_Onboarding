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
     * The distro's identity: name, theme, welcome page and featured slides.
     *
     * Unlike workflows, branding is compiled into the binary rather than read
     * from disk. A distro owner points the build at their own branding directory
     * and ships the result, so a build's identity is fixed and cannot be missing
     * or altered at runtime:
     *
     *     meson setup build -Dbranding_dir=/path/to/their-branding
     *
     * The directory holds branding.conf (this file's schema), a welcome.html, a
     * theme.css layered over the app's own stylesheet, and slides/*.html.
     */
    public class Branding : GLib.Object {

        public const string RESOURCE_ROOT = APP_PATH + "/branding";

        /**
         * What a build claims when branding.conf declares no Version, and what a
         * slide's Since defaults to. Below every version a distro can write, so
         * an unversioned build gates nothing and an unversioned slide is only
         * ever part of a first run.
         */
        private const string UNVERSIONED = "0";

        private const string SLIDES_GROUP = "Slides";

        private static Branding? instance = null;

        /**
         * The distro's name. The one identity string that stays out here rather
         * than moving into the welcome page's markup, because the catalogue and
         * the startup log need it where no WebView is involved.
         */
        public string name             { get; private set; default = "Linux"; }

        /**
         * The branding's own version, dotted-numeric. Not the application's: it
         * moves when this directory's slides change and stays put for a binary
         * bugfix release, which is the only way a distro can add a slide without
         * either re-showing the whole deck or showing nothing at all.
         */
        public string version          { get; private set; default = UNVERSIONED; }

        /** Resource path of the welcome page, or "" when none is bundled. */
        public string welcome_resource { get; private set; default = ""; }

        public string theme_resource   { get; private set; default = ""; }

        /**
         * The window background, as a colour GDK can parse, or "" to follow the
         * user's GTK theme.
         *
         * Here rather than inferred from theme.css because nothing in this app
         * parses CSS: this is the colour painted where the app's own content has
         * not painted yet, and a distro shipping a dark sheet has to be able to
         * name it. See Palette, which is the only reader.
         */
        public string background       { get; private set; default = ""; }

        /**
         * The accent colour, as #rrggbb, or "" to follow the desktop.
         *
         * Setting it is how a distro opts out of per-desktop accenting: it wins
         * over anything read from GNOME or KDE. See Palette.
         */
        public string accent           { get; private set; default = ""; }

        /**
         * "desktop" (default), "light" or "dark". Whether the deck follows the
         * desktop into dark mode or insists on one of them.
         */
        public string color_scheme     { get; private set; default = "desktop"; }
        public bool   allow_slide_scripts { get; private set; default = false; }
        public string marketplace_name { get; private set; default = ""; }
        public string marketplace_url  { get; private set; default = ""; }

        /** Slide resource paths, in presentation order. May be empty. */
        public string[] slides { get; private set; }

        /**
         * The branding version each entry of `slides` first appeared in, same
         * length and same order. UNVERSIONED for a slide that declares none.
         */
        public string[] slide_since { get; private set; }

        public static Branding get_default () {
            if (instance == null) instance = new Branding ();
            return instance;
        }

        private Branding () {
            slides = {};
            slide_since = {};

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

            name = read (keyfile, "Branding", "Name", name);

            var declared = read (keyfile, "Branding", "Version", UNVERSIONED);
            if (Version.is_valid (declared)) {
                version = declared;
            } else {
                // Left at UNVERSIONED rather than guessed at: no Since can then
                // sit above it, so the deck degrades to first-run-only instead of
                // showing an arbitrary subset the author never chose.
                warning ("branding.conf: Version=%s is not dotted-numeric; no slide " +
                         "in this build will ever count as new", declared);
            }

            // The welcome page is HTML, so the logo and tagline that once had
            // keys here are markup inside it. An explicit empty value is a
            // distro choosing to open on its slides instead.
            var welcome = read (keyfile, "Branding", "Welcome", "welcome.html");
            if (welcome != "") {
                var welcome_path = RESOURCE_ROOT + "/" + welcome;
                if (resource_exists (welcome_path)) welcome_resource = welcome_path;
                else warning ("branding.conf: Welcome names '%s', which is not bundled", welcome);
            }

            var theme = read (keyfile, "Branding", "Theme", "");
            if (theme != "") theme_resource = RESOURCE_ROOT + "/" + theme;

            background   = read (keyfile, "Branding", "Background", "");
            accent       = read (keyfile, "Branding", "Accent", "");
            color_scheme = read (keyfile, "Branding", "ColorScheme", "desktop");

            allow_slide_scripts = read (keyfile, "Branding", "AllowSlideScripts", "false").down () == "true";

            marketplace_name = read (keyfile, "Marketplace", "Name", "");
            marketplace_url  = read (keyfile, "Marketplace", "Url", "");

            slides = resolve_slides (read (keyfile, "Branding", "SlideOrder", ""));
            slide_since = resolve_since (keyfile);

            message ("branding: %s %s, %d slide(s)%s", name, version, slides.length,
                     allow_slide_scripts ? ", scripts enabled" : "");
        }

        /**
         * The slides owed to a user whose last-seen branding version is
         * `last_seen`, in deck order.
         *
         * null means no state file, which means nobody has been shown anything on
         * this machine — so the answer is every slide with Since ignored (D10). A
         * genuine first-run user gets the whole introduction; only an upgrader
         * gets a delta. Treating a first run as "seen version 0" instead would
         * hide every slide a distro forgot to mark, which is most of them.
         */
        public string[] slides_for (string? last_seen) {
            if (last_seen == null) return slides;

            string[] result = {};
            for (int i = 0; i < slides.length; i++)
                if (Version.is_above (slide_since[i], last_seen)) result += slides[i];
            return result;
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

        /**
         * Since= for every entry of `slides`, read from a [Slides] group keyed by
         * filename.
         *
         * Its own group rather than a second list beside SlideOrder: SlideOrder is
         * a positional `;`-separated list, and a parallel list of versions
         * mis-pairs silently the moment someone inserts one slide and forgets the
         * other — the failure being an existing slide re-shown and a new one
         * hidden, with nothing to read in a diff. Keying by filename also keeps
         * the versions meaningful when SlideOrder is omitted entirely and the
         * directory is enumerated instead, which a parallel list cannot do at all.
         */
        private string[] resolve_since (KeyFile kf) {
            string[] result = {};
            foreach (var resource in slides) {
                var slide = Path.get_basename (resource);
                var declared = read (kf, SLIDES_GROUP, slide, UNVERSIONED);
                if (!Version.is_valid (declared)) {
                    warning ("branding.conf: [Slides] %s=%s is not dotted-numeric; " +
                             "treating the slide as unversioned", slide, declared);
                    declared = UNVERSIONED;
                }
                result += declared;
            }
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
