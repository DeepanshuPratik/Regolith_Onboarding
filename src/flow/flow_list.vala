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
     * The workflow catalogue, plus a tile explaining how to install more.
     *
     * Both views live in one Gtk.Stack rather than a dialog. A dialog would be a
     * second toplevel, and this window is a gtk-layer-shell surface — the same
     * property that makes portal calls fatal here makes extra toplevels a risk
     * not worth taking for a panel of text.
     */
    public class WorkFlows : Box {
      public delegate void workflowElement(Workflow workflow);

      private const int TILE_WIDTH = 300;
      private const int TILE_HEIGHT = 150;

      private Gtk.Stack stack;
      private Gtk.Grid grid;
      private Gtk.Label headerText;
      private workflowElement on_selected;
      private WorkflowLocator locator = new WorkflowLocator ();

      public WorkFlows(Gee.List<Workflow> workflowList, owned workflowElement workflow_element){
        Object(orientation: Gtk.Orientation.VERTICAL, spacing: 20);
        this.set_margin_start(20);
        this.set_margin_bottom(20);
        this.set_margin_top(20);
        this.set_margin_end(20);
        this.on_selected = (owned) workflow_element;

        bool can_practice = CaptureBackends.supported ();

        headerText = new Label(can_practice ? "Select a Workflow to Practice"
                                            : "Keyboard Shortcuts");
        headerText.get_style_context().add_class("title-1");
        this.add(headerText);

        if (!can_practice) {
          var notice = new Label(CaptureBackends.unsupported_reason ());
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

        stack = new Gtk.Stack();
        stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE);
        stack.add_named(scrolledWindow, "list");
        stack.add_named(build_marketplace_panel(), "marketplace");
        this.add(stack);

        populate(workflowList);
      }

      private void populate(Gee.List<Workflow> workflowList) {
        foreach (var child in grid.get_children()) grid.remove(child);

        int columns = (workflowList.size > 3) ? 2 : 1;
        int i = 0;

        foreach (var item in workflowList) {
           var label = new Label(item.name);
           label.get_style_context().add_class("heading");

           // Images resolve against wherever the workflow came from, so a
           // user-installed workflow can ship its own artwork.
           var thumbnail = item.load_image(item.image, TILE_WIDTH, TILE_HEIGHT);

           var button = new Button();
           button.get_style_context().add_class("workflow-button");
           button.set_tooltip_text(item.description);

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

      // The "install more" affordance. Sized like a workflow tile so it reads as
      // part of the catalogue rather than a stray control.
      private Gtk.Button build_add_tile(bool catalogue_is_empty) {
        var plus = new Label("+");
        plus.get_style_context().add_class("add-tile-plus");

        var caption = new Label(catalogue_is_empty
            ? "No workflows yet — add some"
            : "Add more workflows");
        caption.get_style_context().add_class("heading");
        caption.wrap = true;
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
        button.clicked.connect(() => { stack.set_visible_child_name("marketplace"); });
        return button;
      }

      /**
       * Tells the user how to install workflows and does nothing else.
       *
       * Deliberately no downloading and no running of anything: these are
       * community-authored files, and fetching or executing them on someone's
       * behalf — from a button they cannot read the contents of first — is not a
       * decision this app should make for them. The commands are shown so the
       * user runs them knowingly. The only outbound action here is handing a URL
       * to the system browser.
       */
      private Gtk.Widget build_marketplace_panel() {
        var branding = Branding.get_default ();
        var install_dir = locator.user_install_dir ();

        var panel = new Box(Gtk.Orientation.VERTICAL, 12);
        panel.set_valign(Gtk.Align.CENTER);

        var title = new Label(branding.marketplace_name != ""
            ? branding.marketplace_name
            : "Add More Workflows");
        title.get_style_context().add_class("title-1");
        panel.add(title);

        var blurb = new Label(
            "Workflows are plain JSON files. Drop them in the folder below and they "
            + "appear here alongside the built-in ones.");
        blurb.get_style_context().add_class("text-secondary");
        blurb.wrap = true;
        blurb.max_width_chars = 64;
        blurb.justify = Gtk.Justification.CENTER;
        panel.add(blurb);

        var command = build_command(branding.marketplace_url, install_dir);

        var command_view = new Label(command);
        command_view.get_style_context().add_class("command-block");
        command_view.selectable = true;
        command_view.wrap = true;
        command_view.max_width_chars = 68;
        command_view.xalign = 0;
        panel.add(command_view);

        var caution = new Label(
            "This app does not download or run anything for you. Read what you are "
            + "installing, then run these yourself.");
        caution.get_style_context().add_class("notice");
        caution.wrap = true;
        caution.max_width_chars = 64;
        caution.justify = Gtk.Justification.CENTER;
        panel.add(caution);

        var buttons = new Box(Gtk.Orientation.HORIZONTAL, 8);
        buttons.set_halign(Gtk.Align.CENTER);

        var back = new Button.with_label("Back");
        back.get_style_context().add_class("cancelButton");
        back.clicked.connect(() => { stack.set_visible_child_name("list"); });
        buttons.add(back);

        var copy = new Button.with_label("Copy Commands");
        copy.get_style_context().add_class("cancelButton");
        copy.clicked.connect(() => {
            Gtk.Clipboard.get_default(this.get_display()).set_text(command, -1);
            copy.set_label("Copied");
        });
        buttons.add(copy);

        if (branding.marketplace_url != "") {
          var open = new Button.with_label("Open in Browser");
          open.get_style_context().add_class("pill-button");
          open.get_style_context().add_class("suggested-action");
          open.clicked.connect(() => {
              // Not show_uri_on_window(): see SlidePage for why that is fatal here.
              try {
                  AppInfo.launch_default_for_uri(branding.marketplace_url, null);
              } catch (Error e) {
                  warning("Cannot open marketplace URL: %s", e.message);
              }
          });
          buttons.add(open);
        }

        var rescan = new Button.with_label("Rescan");
        rescan.get_style_context().add_class("cancelButton");
        rescan.set_tooltip_text("Pick up files you just copied, without restarting");
        rescan.clicked.connect(() => {
            populate(locator.load ());
            stack.set_visible_child_name("list");
        });
        buttons.add(rescan);

        panel.add(buttons);
        return panel;
      }

      // The detected desktop is substituted in, so the commands are paste-ready.
      private string build_command(string url, string install_dir) {
        var desktop_id = Path.get_basename(install_dir);
        var sb = new StringBuilder();
        sb.append("mkdir -p ").append(install_dir).append("\n");
        if (url != "") {
            sb.append("git clone ").append(url).append(" /tmp/onboarding-marketplace\n");
            sb.append("cp /tmp/onboarding-marketplace/workflows/")
              .append(desktop_id).append("/*.json \\\n    ")
              .append(install_dir).append("/");
        } else {
            sb.append("# then copy any workflow .json files into that folder");
        }
        return sb.str;
      }
    }
}
