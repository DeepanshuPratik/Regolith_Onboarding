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
     * Any Wayland session, whatever compositor is running it.
     *
     * A display-server layer rather than a desktop: it sits near the bottom of
     * the registry's list and contributes the one capability that is decided by
     * the protocol in use rather than by the desktop on top of it. Every Wayland
     * desktop here gets its window placement from this, and a compositor that
     * wants different placement overrides it simply by being listed above.
     *
     * It observes nothing and dispatches nothing on purpose. A Wayland
     * compositor with no IPC we understand consumes its own shortcuts before any
     * client sees them, and there is no portable way to observe a shortcut the
     * compositor owns — the GlobalShortcuts portal registers new bindings, it
     * does not report existing ones.
     */
    public class WaylandPlatform : GLib.Object, Platform {

        public string id () { return "wayland"; }

        public bool claims_session () { return Desktop.get_default ().is_wayland; }

        public WindowPlacer? placer (Gtk.Window window) {
            return new LayerShellPlacer (window);
        }
    }
}
