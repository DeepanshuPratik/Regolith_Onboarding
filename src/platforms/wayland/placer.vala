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
   *
   * ==> Why sway is not driven through swaymsg instead. <==
   *
   * sway's `move` and `resize` commands address containers in its tree, and a
   * layer-shell surface is not in that tree: it has no app_id, `get_tree` does
   * not list it, and no criteria can select it. An IPC placer could therefore
   * only work by giving up the layer surface — and with it the EXCLUSIVE
   * keyboard mode that is the only reason practice can see a compositor-owned
   * shortcut on sway at all. Trading observation away for placement is the same
   * bad bargain that got the XWayland route rejected on GNOME.
   *
   * The IPC route was measured all the same (#12), on an ordinary view, and what
   * it found is recorded here so that nobody has to measure it twice before
   * arriving at the same conclusion: `move position` is workspace-relative, so
   * `move absolute position` is the one that takes global coordinates; `resize
   * set` resizes about the window's CENTRE, so a resize belongs before its move
   * rather than after it; `for_window` rules fire only at window creation and so
   * cannot drive a runtime shrink at all; and all three commands chain in a
   * single swaymsg call with no settling delay.
   */
  public class LayerShellPlacer : GLib.Object, WindowPlacer {

    // The practice card: small enough to leave the desktop usable, large enough
    // to keep one step legible.
    private const int CARD_WIDTH = 200;
    private const int CARD_HEIGHT = 150;

    private Gtk.Window window;

    // What to put back, and whether there is anything to put back.
    //
    // The size request is the right thing to save because it is the thing this
    // placer changes — a layer-shell window is sized by its request rather than
    // by a rectangle it names. Saving it also stops this file and the toplevel's
    // own default size from drifting apart the day one of the two is edited.
    private int normal_width = 0;
    private int normal_height = 0;
    private bool shrunk = false;

    public LayerShellPlacer (Gtk.Window window) {
      this.window = window;
    }

    /**
     * False on a Wayland compositor that implements no layer shell, so the
     * registry's walk falls past this to a placer that works — on Mutter, the
     * ResizeOnlyPlacer next door. Answering true here would hand back a placer
     * whose every method aborts the process.
     */
    public bool available () { return LayerShellSupport.available (); }

    public string unavailable_reason () {
      return "This compositor does not implement the layer-shell protocol, so the shortcut card cannot move itself out of the way.";
    }

    public bool shrink_for_practice () {
      if (!usable ()) return false;
      // Idempotent, and not merely for tidiness: a second shrink would otherwise
      // save the card's own size as the normal one, leaving restore() with
      // nothing to grow the window back to.
      if (shrunk) return true;

      window.get_size_request (out normal_width, out normal_height);
      shrunk = true;

      GtkLayerShell.set_anchor (window, GtkLayerShell.Edge.TOP, true);
      window.set_size_request (CARD_WIDTH, CARD_HEIGHT);
      // resize(1, 1) rather than resize(CARD_WIDTH, CARD_HEIGHT): a request below
      // the widget's minimum is clamped up to it, so asking for the smallest
      // window imaginable is how the size request above is made to win.
      window.resize (1, 1);
      return true;
    }

    public bool restore () {
      if (!usable ()) return false;
      // Nothing was shrunk, so there is nothing to put back. This is the whole of
      // the contract's "safe without a preceding shrink, and safe to call twice":
      // restore() is reached from the cancel button, from the observer's aborted
      // signal and from the step-advance timeout, and any pair of those can fire.
      if (!shrunk) return true;
      shrunk = false;

      GtkLayerShell.set_anchor (window, GtkLayerShell.Edge.TOP, false);
      window.set_size_request (normal_width, normal_height);
      window.resize (1, 1);
      return true;
    }

    /**
     * Both that the compositor carries the protocol and that this window was
     * built on it.
     *
     * The second half is not paranoia about the registry handing out a placer
     * whose available() said false. set_anchor() on a window that never got
     * init_for_window() fails the way everything else in gtk-layer-shell fails —
     * a CRITICAL, a normal return, and then an abort out of some later roundtrip
     * rather than out of the line that caused it. See LayerShellSupport.
     */
    private bool usable () {
      return LayerShellSupport.available () && GtkLayerShell.is_layer_window (window);
    }
  }
}
