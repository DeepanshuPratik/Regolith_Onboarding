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
using Gee;

namespace linux_onboarding {

    /**
     * The workflow catalogue.
     *
     * The `+` tile used to switch to a second Stack page showing copy-paste
     * install commands. D7 ruled that out: the app ships no install mechanism,
     * the marketplace's own README documents the manual fetch-and-place
     * command, and a button that runs cp on a marketplace URL was both more
     * and less than a download manager should be. The tile now hands the URL
     * to the system browser and quits, and the rest of the panel is gone.
     */
    public class WorkFlows : Box {
      public delegate void workflowElement(Workflow workflow);

      /**
       * Tile thumbnail size, at the same 3:2 the practice slot uses.
       *
       * It was 300x150 — 2:1 — which letterboxed every asset authored for the
       * demo slot, so each tile carried a band of empty space.
       *
       * Small enough that two rows of three fit the window outright, which
       * matters more than it sounds: when the rows do not fit, GTK does not
       * scroll, it *squeezes*. The second row then loses its captions and the
       * add tile's plus is clipped to a sliver — which is exactly what made that
       * tile look like a stray dot on the panel. The scroll view underneath is a
       * safety net for a catalogue with many workflows, not the normal case.
       */
      private const int TILE_WIDTH = 210;
      private const int TILE_HEIGHT = 140;

      private Gtk.Grid grid;
      private Gtk.Label headerText;
      private workflowElement on_selected;

      public WorkFlows(Gee.List<Workflow> workflowList, owned workflowElement workflow_element){
        Object(orientation: Gtk.Orientation.VERTICAL, spacing: 20);
        this.set_margin_start(20);
        this.set_margin_bottom(20);
        this.set_margin_top(20);
        this.set_margin_end(20);
        this.on_selected = (owned) workflow_element;

        bool can_practice = PlatformRegistry.can_practice ();

        headerText = new Label(can_practice ? "Select a Workflow to Practice"
                                            : "Keyboard Shortcuts");
        headerText.get_style_context().add_class("title-1");
        this.add(headerText);

        if (!can_practice) {
          var notice = new Label(PlatformRegistry.no_practice_reason ());
          notice.get_style_context().add_class("notice");
          notice.wrap = true;
          notice.justify = Gtk.Justification.CENTER;
          notice.max_width_chars = 60;
          this.add(notice);
        }

        grid = new Gtk.Grid();
        grid.set_column_spacing(20);
        grid.set_row_spacing(20);

        var scrolledWindow = new Gtk.ScrolledWindow(null, null);
        scrolledWindow.add(grid);
        scrolledWindow.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scrolledWindow.set_vexpand(true);

        this.add(scrolledWindow);

        populate(workflowList);
      }

      private void populate(Gee.List<Workflow> workflowList) {
        foreach (var child in grid.get_children()) grid.remove(child);

        // Counting the add tile, because it is the thing that ends up orphaned
        // on a row of its own when the count is only of workflows.
        int total = workflowList.size + 1;
        int columns = (total <= 2) ? total : (total <= 4 ? 2 : 3);
        int i = 0;

        foreach (var item in workflowList) {
           var label = new Label(item.name);
           label.get_style_context().add_class("heading");

           // Images resolve against wherever the workflow came from, so a
           // user-installed workflow can ship its own artwork.
           var thumbnail = item.load_thumbnail(item.image, TILE_WIDTH, TILE_HEIGHT);

           var button = new Button();
           button.get_style_context().add_class("workflow-button");
           button.set_tooltip_text("%s — %s".printf (item.name, item.description));

           // One line, ellipsised. A wrapping caption made the row as tall as
           // the longest name, and when that did not fit GTK squeezed the row
           // and clipped every caption in it — "Settings at Your Fingertips"
           // was enough to do it. The full name is in the tooltip.
           label.set_line_wrap (false);
           label.set_ellipsize (Pango.EllipsizeMode.END);
           label.max_width_chars = 22;
           label.justify = Gtk.Justification.CENTER;

           var tile = new Grid();
           tile.set_row_spacing(10);
           tile.attach(thumbnail, 0, 0, 1, 1);
           tile.attach(label, 0, 1, 1, 1);
           button.add(tile);

           button.clicked.connect((btn) => { on_selected(item); });
           grid.attach(button, i % columns, i / columns, 1, 1);
           i++;
        }

        grid.attach(build_add_tile(workflowList.size == 0), i % columns, i / columns, 1, 1);
        grid.show_all();
      }

      /**
       * The "install more" affordance. Sized like a workflow tile so it reads as
       * part of the catalogue rather than a stray control.
       *
       * Opens the marketplace URL in the user's real browser and quits the app.
       * The user does the install themselves — see the marketplace section of
       * docs/DISTRO-GUIDE.md. Nothing is downloaded or executed by the app.
       */
      private Gtk.Button build_add_tile(bool catalogue_is_empty) {
        // An icon rather than a "+" label. The label was a 44px font whose glyph
        // rendered as 21x12 pixels of ink — a plus fills very little of its own
        // em box, and what was left after the row squeezed it read as a stray
        // dash on the panel rather than as an affordance. An icon has a pixel
        // size that means what it says.
        var plus = new Gtk.Image.from_icon_name("list-add-symbolic", Gtk.IconSize.DIALOG);
        plus.pixel_size = 48;
        plus.get_style_context().add_class("add-tile-plus");

        var caption = new Label(catalogue_is_empty
            ? "No workflows yet"
            : "Add more workflows");
        caption.get_style_context().add_class("heading");
        caption.set_line_wrap (false);
        caption.set_ellipsize (Pango.EllipsizeMode.END);
        caption.max_width_chars = 22;
        caption.justify = Gtk.Justification.CENTER;

        var inner = new Box(Gtk.Orientation.VERTICAL, 10);
        inner.set_size_request(TILE_WIDTH, TILE_HEIGHT);
        inner.set_valign(Gtk.Align.CENTER);
        inner.add(plus);

        var tile = new Grid();
        tile.set_row_spacing(10);
        tile.attach(inner, 0, 0, 1, 1);
        tile.attach(caption, 0, 1, 1, 1);

        var button = new Button();
        button.get_style_context().add_class("workflow-button");
        button.get_style_context().add_class("add-tile");
        button.add(tile);
        button.clicked.connect(() => { open_marketplace_and_quit (); });
        return button;
      }

      /**
       * The entire "outbound" action this app takes. Hands the URL to the
       * system browser, then exits through the same path every other quit
       * does — release_practice() removes the binding mode, so closing the
       * window from the browser side cannot strand it in config.d.
       *
       * Not Gtk.show_uri_on_window(): that exports a window handle via
       * xdg-foreign for the OpenURI portal, which a gtk-layer-shell surface
       * cannot do, and the compositor kills us for trying. The slide deck
       * makes the same call for the same reason — see SlidePage.
       */
      private void open_marketplace_and_quit () {
        var url = Branding.get_default ().marketplace_url;
        if (url == "") {
          warning ("marketplace tile clicked, but no marketplace_url is configured");
          return;
        }
        try {
          AppInfo.launch_default_for_uri (url, null);
        } catch (Error e) {
          warning ("Cannot open marketplace URL: %s", e.message);
          return;
        }
        Gtk.main_quit ();
      }
    }
}
