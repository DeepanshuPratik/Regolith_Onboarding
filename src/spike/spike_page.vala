/****************************************************************************************
 * PHASE 0 SPIKE — throwaway. Verifies WebKitWebView is usable in this application's
 * window setup before the slide feature is built on top of it. Superseded by
 * src/slides/ once the findings are in.
 *
 * Answers, side by side:
 *   left  column — file:// load from an on-disk path (the easy baseline)
 *   right column — app:// load served out of GResource via a custom URI scheme,
 *                  which is what build-time-bundled slides actually require
 ****************************************************************************************/
using Gtk;

namespace linux_onboarding {

    public class SpikePage : Box {

        private static bool scheme_registered = false;

        // WebKit cannot load resource:// URIs, so bundled slides need a custom scheme
        // that serves bytes straight out of GResource.
        private static void register_app_scheme () {
            if (scheme_registered) return;
            scheme_registered = true;

            var ctx = WebKit.WebContext.get_default ();
            ctx.register_uri_scheme ("app", (req) => {
                var path = req.get_path ();
                while (path.has_prefix ("/")) path = path.substring (1);
                var res_path = APP_PATH + "/spike/" + path;
                try {
                    var bytes = GLib.resources_lookup_data (res_path, 0);
                    req.finish (new MemoryInputStream.from_bytes (bytes),
                                (int64) bytes.get_size (),
                                content_type_for (path));
                    stdout.printf ("[SPIKE] app:// served %s (%" + size_t.FORMAT + " bytes)\n",
                                   res_path, bytes.get_size ());
                } catch (Error e) {
                    stderr.printf ("[SPIKE] app:// FAILED for %s: %s\n", res_path, e.message);
                    req.finish_error (e);
                }
            });

            // Custom schemes are opaque origins by default; without this the page can be
            // refused access to its own stylesheet and images. Checklist item 5.
            ctx.get_security_manager ().register_uri_scheme_as_local ("app");
        }

        private static string content_type_for (string path) {
            if (path.has_suffix (".html")) return "text/html";
            if (path.has_suffix (".css"))  return "text/css";
            if (path.has_suffix (".png"))  return "image/png";
            if (path.has_suffix (".svg"))  return "image/svg+xml";
            return "application/octet-stream";
        }

        public SpikePage (string spike_dir_abs) {
            Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 10);
            this.margin = 10;
            register_app_scheme ();

            add (make_column ("file://", "file://" + spike_dir_abs + "/spike.html"));
            add (make_column ("app://",  "app:///spike.html"));
        }

        private Gtk.Box make_column (string title, string uri) {
            var col = new Box (Gtk.Orientation.VERTICAL, 4);
            var lbl = new Label (title);
            lbl.get_style_context ().add_class ("heading");
            col.add (lbl);

            var view = new WebKit.WebView ();
            var s = view.get_settings ();
            s.enable_javascript = true;   // spike only: the page reports its own scheme
            s.enable_developer_extras = false;
            view.set_size_request (360, 320);
            view.expand = true;

            // Checklist item: external links must reach the real browser, not navigate
            // the onboarding window into becoming one.
            view.decide_policy.connect ((decision, type) => {
                if (type != WebKit.PolicyDecisionType.NAVIGATION_ACTION) return false;
                var nav = (WebKit.NavigationPolicyDecision) decision;
                var target = nav.get_request ().get_uri ();
                if (target.has_prefix ("http://") || target.has_prefix ("https://")) {
                    stdout.printf ("[SPIKE] external link intercepted: %s\n", target);
                    // NOT Gtk.show_uri_on_window(): it exports a window handle via
                    // xdg-foreign for the OpenURI portal, and a gtk-layer-shell surface
                    // is not an xdg_toplevel — the export is a protocol violation and
                    // the compositor disconnects us (Wayland error 71).
                    // AppInfo needs no window handle at all.
                    try {
                        AppInfo.launch_default_for_uri (target, null);
                        stdout.printf ("[SPIKE] handed to default handler OK\n");
                    } catch (Error e) {
                        stderr.printf ("[SPIKE] launch_default_for_uri: %s\n", e.message);
                    }
                    decision.ignore ();
                    return true;
                }
                return false;
            });

            view.load_failed.connect ((ev, failing_uri, err) => {
                stderr.printf ("[SPIKE] LOAD FAILED %s: %s\n", failing_uri, err.message);
                return false;
            });

            view.load_changed.connect ((ev) => {
                if (ev == WebKit.LoadEvent.FINISHED)
                    stdout.printf ("[SPIKE] loaded OK: %s\n", view.get_uri ());
            });

            // Checklist item 6: does the WebView swallow keys? The window-level handler
            // at onboardingWindow.vala uses Escape to quit and clean up WM config, so a
            // WebView that eats keypresses would strand a mode block in config.d.
            view.key_press_event.connect ((key) => {
                stdout.printf ("[SPIKE] WebView saw keyval %u (Escape is %d)\n",
                               key.keyval, KEY_CODE_ESCAPE);
                return false;
            });

            col.add (view);
            view.load_uri (uri);
            return col;
        }
    }
}
