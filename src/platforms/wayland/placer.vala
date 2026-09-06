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
using GtkLayerShell;

namespace linux_onboarding {

  /**
   * Placement through the layer-shell protocol: anchor the window to the top
   * edge to get it out of the way, un-anchor it to bring it back.
   *
   * A layer-shell client never names coordinates — it names an edge and lets the
   * compositor do the arithmetic — which is why this asks for an anchor and a
   * size request and then resizes to 1x1 to let the size request win.
   *
   * Deliberately not under src/platforms/sway/, even though sway is the desktop
   * that reaches it in practice. Nothing here is sway-specific; it is what any
   * Wayland compositor implementing layer shell gets, and putting it in the sway
   * directory would mean the next compositor to arrive had to either copy it or
   * reach across into a neighbour's directory for it.
   */
  public class LayerShellPlacer : GLib.Object, WindowPlacer {

    private Gtk.Window window;

    public LayerShellPlacer (Gtk.Window window) {
      this.window = window;
    }

    /**
     * False on a Wayland compositor that implements no layer shell, so the
     * registry's walk falls past this to a placer that works — in practice the
     * NullPlacer, which centres the window and says so. Answering true here
     * would hand back a placer whose every method aborts the process.
     */
    public bool available () { return LayerShellSupport.available (); }

    public string unavailable_reason () {
      return "This compositor does not implement the layer-shell protocol, so the shortcut card cannot move itself out of the way.";
    }

    public bool shrink_for_practice () {
      // Guarded even though the registry only hands out available() placers:
      // set_anchor on a window that never got init_for_window is the same staged
      // failure as everything else here — a CRITICAL, a normal return, and then
      // an abort out of the resize below rather than out of this line.
      if (!LayerShellSupport.available ()) return false;

      GtkLayerShell.set_anchor (window, GtkLayerShell.Edge.TOP, true);
      window.set_size_request (200, 150);
      window.resize (1, 1);
      return true;
    }

    public bool restore () {
      if (!LayerShellSupport.available ()) return false;

      GtkLayerShell.set_anchor (window, GtkLayerShell.Edge.TOP, false);
      window.set_size_request (800, 450);
      window.resize (1, 1);
      return true;
    }
  }
}
