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
     * The one place that answers "what colour is this app?".
     *
     * It exists for the startup flash (#33). A WebKit.WebView's default base
     * colour is opaque white, so the deck used to open as a white rectangle and
     * repaint into the real page — worst on exactly the builds that look best,
     * because a dark branding makes the white maximally visible. Fixing that
     * means telling the view what colour to be *before* it has a document, which
     * means somewhere has to know the app's background outside CSS.
     *
     * Deliberately a lookup and not a constant. Three sources, in order:
     *
     *  1. `Background=` in branding.conf. A distro that ships a dark theme.css
     *     has to be able to say so: nothing here parses CSS, so the sheet's own
     *     background is invisible to us, and guessing it from the GTK theme gets
     *     a light colour behind a dark page.
     *  2. The GTK theme's own `theme_bg_color`, which is what app.css asks for
     *     when a distro sets no Background. Following the user's theme is the
     *     right default for an unbranded build.
     *  3. A neutral mid-grey, if even that lookup fails. Never white: white is
     *     the failure this class exists to prevent, and a wrong grey is a much
     *     smaller error than a flash.
     *
     * Resolved once. The branding is compiled in and the GTK theme does not
     * change under us within a run.
     */
    public class Palette : GLib.Object {

        // Not white, on purpose — see the class comment.
        private const string FALLBACK = "#303030";

        private static Gdk.RGBA? cached = null;

        /**
         * The colour to paint where the app's own content has not painted yet.
         *
         * Safe to call before any window is realised: the theme lookup goes
         * through a throwaway widget's style context, which resolves against the
         * default screen's providers and needs no toplevel.
         */
        public static Gdk.RGBA window_background () {
            if (cached != null) return cached;

            var rgba = Gdk.RGBA ();

            var declared = Branding.get_default ().background;
            if (declared != "" && rgba.parse (declared)) {
                cached = rgba;
                return cached;
            }
            if (declared != "") {
                warning ("branding.conf: Background=%s is not a colour GDK understands; " +
                         "falling back to the GTK theme", declared);
            }

            // A Label rather than a Window: constructing a Gtk.Window here would
            // put a second toplevel in the application's window list.
            var probe = new Gtk.Label ("");
            if (probe.get_style_context ().lookup_color ("theme_bg_color", out rgba)) {
                cached = rgba;
                return cached;
            }

            rgba.parse (FALLBACK);
            cached = rgba;
            return cached;
        }
    }
}
