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

namespace linux_onboarding {

    /**
     * Serves the compiled-in branding bundle to WebKit over an "app://" scheme.
     *
     * WebKit cannot load resource:// URIs, and branding is deliberately compiled
     * in rather than written to disk, so a custom scheme is the way to bridge the
     * two. Slides then reference their assets relatively — <img src="assets/x.png">
     * resolves to app:///slides/assets/x.png — exactly as they would on a filesystem.
     *
     * One host inside the scheme is reserved: app://action/<name> is not a file
     * but a message back to the app, so a page can drive the deck with a plain
     * link and no scripting. SlidePage's decide_policy claims those.
     */
    public class SlideScheme : GLib.Object {

        public const string SCHEME = "app";

        /** Reserved host: app://action/<name> addresses the app, not the bundle. */
        public const string ACTION_HOST = "action";

        /**
         * Reserved path: app:///palette.css is generated per session rather than
         * looked up in the bundle. A distro page links it to pick up the
         * desktop's accent; a distro that does not link it is unaffected.
         */
        public const string PALETTE_FILE = "palette.css";

        private static bool registered = false;

        public static void register () {
            if (registered) return;
            registered = true;

            var ctx = WebKit.WebContext.get_default ();

            ctx.register_uri_scheme (SCHEME, (request) => {
                // Link clicks never arrive here — decide_policy claims them
                // first — but a stylesheet or <img> pointing at the action host
                // would, and it deserves a truthful message rather than the
                // "asset not bundled" warning below.
                if (action_in (request.get_uri ()) != null) {
                    warning ("%s is an action link, not an asset; it cannot be loaded",
                             request.get_uri ());
                    request.finish_error (new IOError.NOT_SUPPORTED ("action host is not a resource"));
                    return;
                }

                var path = request.get_path ();
                while (path.has_prefix ("/")) path = path.substring (1);

                // One generated sheet alongside the bundled files: the desktop's
                // accent, so a slide can match the window it sits in (#32). Not a
                // file in the branding directory because its content depends on
                // the session, which is exactly what a compiled-in bundle cannot
                // express.
                if (path == PALETTE_FILE) {
                    var css = Palette.web_palette_css ().data;
                    request.finish (new MemoryInputStream.from_data (css, null),
                                    css.length, "text/css");
                    return;
                }

                var resource = Branding.RESOURCE_ROOT + "/" + path;
                try {
                    var bytes = GLib.resources_lookup_data (resource, ResourceLookupFlags.NONE);
                    request.finish (new MemoryInputStream.from_bytes (bytes),
                                    (int64) bytes.get_size (),
                                    content_type_for (path));
                } catch (Error e) {
                    warning ("slide asset not bundled: %s", resource);
                    request.finish_error (e);
                }
            });

            // Without this the scheme is an opaque origin and a slide is refused
            // access to its own stylesheet and images.
            ctx.get_security_manager ().register_uri_scheme_as_local (SCHEME);
        }

        /** app:// URI for a resource path inside the branding bundle. */
        public static string uri_for (string resource_path) {
            var relative = resource_path;
            if (relative.has_prefix (Branding.RESOURCE_ROOT))
                relative = relative.substring (Branding.RESOURCE_ROOT.length);
            while (relative.has_prefix ("/")) relative = relative.substring (1);
            return SCHEME + ":///" + relative;
        }

        /**
         * The action name in an app://action/<name> URI, or null when the URI
         * addresses something else. Empty means the host with no name at all,
         * which the caller should complain about rather than act on.
         */
        public static string? action_in (string uri) {
            var host = SCHEME + "://" + ACTION_HOST;
            if (!uri.has_prefix (host)) return null;

            var rest = uri.substring (host.length);
            // Guard against app://actionable/... being mistaken for the host.
            if (rest != "" && rest[0] != '/' && rest[0] != '?' && rest[0] != '#')
                return null;

            int cut = rest.index_of_char ('?');
            if (cut >= 0) rest = rest.substring (0, cut);
            cut = rest.index_of_char ('#');
            if (cut >= 0) rest = rest.substring (0, cut);

            while (rest.has_prefix ("/")) rest = rest.substring (1);
            while (rest.has_suffix ("/")) rest = rest.substring (0, rest.length - 1);
            return rest;
        }

        private static string content_type_for (string path) {
            if (path.has_suffix (".html")) return "text/html";
            if (path.has_suffix (".css"))  return "text/css";
            if (path.has_suffix (".js"))   return "application/javascript";
            if (path.has_suffix (".png"))  return "image/png";
            if (path.has_suffix (".jpg") ||
                path.has_suffix (".jpeg")) return "image/jpeg";
            if (path.has_suffix (".gif"))  return "image/gif";
            if (path.has_suffix (".svg"))  return "image/svg+xml";
            if (path.has_suffix (".webp")) return "image/webp";
            if (path.has_suffix (".woff2"))return "font/woff2";
            if (path.has_suffix (".woff")) return "font/woff";
            return "application/octet-stream";
        }
    }
}
