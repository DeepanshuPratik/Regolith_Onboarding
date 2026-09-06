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
     * Walks the user through one workflow, one keybinding at a time.
     *
     * This page owns presentation and step sequencing only. Noticing that the key
     * was actually pressed, performing the action it is normally bound to, and
     * getting the window out of the way are three separate services, each chosen
     * for the running desktop by PlatformRegistry.
     *
     * Observation is handed in rather than built here. The observer's install()
     * writes into the window manager and belongs to the whole run, so it is the
     * app that owns a PracticeSession; a page only borrows it for the length of
     * one workflow, between start() and stop().
     */
    public class WorkFlowPage : Box {

        public delegate void workflowList();

        // How long the tick stays up before the next step is shown.
        private const uint STEP_ADVANCE_DELAY_SECONDS = 2;

        // Current step, unpacked from JSON.
        private string heading = "";
        private string command = " ";
        private string description = " ";
        private string image = "";

        private uint current_key_sequence = 0;
        private bool isPlayed = false;

        private Workflow workflow;
        private Json.Array? steps;
        private PracticeSession practice;
        private WindowPlacer? placer = null;
        private bool capture_started = false;
        private workflowList return_to_list;

        private Gtk.Button play_button;
        private Gtk.Button cancel_button;
        private Gtk.Image demo;
        private Gtk.Box demo_box;
        private Gtk.Box checkedCommand;
        private Gtk.Image checkTicked;
        private Gtk.Box midBox;
        private Gtk.Box instructionAndPlayHolder;
        private Gtk.Box buttonHolder;
        private Label headingLabel;
        private Label commandLabel;
        private Label descriptionLabel;

        public WorkFlowPage(Workflow workflow, PracticeSession practice, owned workflowList workflowList) {
            Object(orientation: Gtk.Orientation.VERTICAL, spacing: 10);
            this.margin = 20;
            this.set_valign(Gtk.Align.CENTER);
            this.set_halign(Gtk.Align.CENTER);
            this.get_style_context().add_class("practice-page");

            this.workflow = workflow;
            this.steps = workflow.steps;
            this.practice = practice;
            this.return_to_list = (owned) workflowList;

            var css_provider = new Gtk.CssProvider();
            css_provider.load_from_resource(APP_PATH + "/css/flow.css");
            Gtk.StyleContext.add_provider_for_screen(this.get_screen(), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);

            if (steps == null || steps.get_length () == 0) return;

            buttonHolder = new Box(Gtk.Orientation.HORIZONTAL, 2);
            var keyspec = new KeySpec();

            process_workflow_sequence(steps.get_element(current_key_sequence).get_object());

            headingLabel = new Label(heading);
            commandLabel = new Label("PRESS: " + keyspec.format_spec_display(command));
            headingLabel.get_style_context().add_class("heading");
            descriptionLabel = new Label(description);
            instructionAndPlayHolder = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
            instructionAndPlayHolder.set_valign(Gtk.Align.CENTER);
            createInstructionBox();
            midBox = new Box(Gtk.Orientation.HORIZONTAL, 20);
            midBox.get_style_context().add_class("contentHolder");

            demo = workflow.load_image(image);
            demo_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 5);
            demo_box.add(demo);
            midBox.add(instructionAndPlayHolder);
            midBox.add(demo_box);
            this.add(midBox);

            bool can_practice = PlatformRegistry.can_practice ();

            cancel_button = new Gtk.Button();
            cancel_button.get_style_context().add_class("cancelButton");
            // With no way to capture the keypress the page is a reference card, so
            // the only sensible control is a way back.
            cancel_button.set_label(can_practice ? "CANCEL" : "BACK");
            play_button = new Button();
            play_button.get_style_context().add_class("playButton");
            play_button.set_label("PLAY");
            if (can_practice) buttonHolder.add(play_button);
            buttonHolder.add(cancel_button);
            buttonHolder.expand = false;
            buttonHolder.set_halign(Gtk.Align.CENTER);
            instructionAndPlayHolder.add(buttonHolder);

            play_button.clicked.connect (on_play);
            cancel_button.clicked.connect (on_cancel);
        }

        // Built on first use rather than in the constructor: both of its methods
        // need a realised toplevel, and this page is constructed before it has one.
        private WindowPlacer window_placer () {
            if (placer == null)
                placer = PlatformRegistry.placer ((Gtk.Window) this.get_toplevel());
            return placer;
        }

        // PLAY shrinks the window out of the way and hands control to the observer
        // so the user can perform the shortcut against their real desktop.
        private void on_play () {
            if (isPlayed) return;

            window_placer ().shrink_for_practice ();

            instructionAndPlayHolder.remove(descriptionLabel);
            checkedCommand.add(checkTicked);
            checkTicked.opacity = 0;
            instructionAndPlayHolder.margin = 0;
            this.margin = 20;
            play_button.margin = 0;
            cancel_button.margin = 0;
            midBox.set_spacing(0);
            midBox.margin = 0;
            this.expand = false;
            this.set_halign(Gtk.Align.CENTER);
            demo_box.remove(demo);
            isPlayed = true;
            play_button.set_label("CAPTURING");

            if (!capture_started) {
                // Connected here rather than in the constructor, and dropped again
                // in finish(): the session outlives this page, so a page that goes
                // away still wired to its signals would be called back after it was
                // destroyed. The install() these signals depend on already happened,
                // at startup.
                practice.step_matched.connect (on_step_matched);
                practice.aborted.connect (on_aborted);
                capture_started = true;

                if (!practice.start ())
                    stderr.printf ("Nothing here can observe the keypress; this step cannot complete.\n");
            }

            practice.arm (command);
            this.show_all();
        }

        // The user pressed the right key: perform the real action, confirm it, and
        // move on after a beat so the tick is actually seen.
        private void on_step_matched () {
            current_key_sequence++;
            practice.dispatch (command);
            handleTick();
            this.show_all();

            GLib.Timeout.add_seconds (STEP_ADVANCE_DELAY_SECONDS, () => {
                if (!(this.get_toplevel() is Gtk.Window)) return false;
                window_placer ().restore ();

                if (current_key_sequence >= steps.get_length()) {
                    finish ();
                    return false;
                }

                reset_ui_for_next_step (steps.get_element(current_key_sequence).get_object());
                return false;
            });
        }

        private void on_aborted () {
            restore_window ();
            finish ();
        }

        private void on_cancel () {
            restore_window ();
            finish ();
        }

        private void restore_window () {
            window_placer ().restore ();
        }

        /**
         * Hands the session back. Only start()'s half is undone — what install()
         * put in the window manager stays there for the next workflow, and comes
         * out when the app exits.
         *
         * Reachable from a signal the session is in the middle of emitting, which
         * is why the disconnect comes first: on_aborted() lands here, and the page
         * is destroyed on the next line.
         */
        private void finish () {
            if (capture_started) {
                practice.step_matched.disconnect (on_step_matched);
                practice.aborted.disconnect (on_aborted);
                practice.stop ();
                capture_started = false;
            }
            return_to_list ();
            this.destroy();
        }

        // Resets all UI labels/images after a step completes and loads the next one.
        private void reset_ui_for_next_step(Json.Object next_obj) {
            var keyspec = new KeySpec();
            process_workflow_sequence(next_obj);
            this.margin = 20;
            play_button.margin_end = 5;
            cancel_button.margin = 0;
            midBox.set_spacing(20);
            midBox.margin = 3;
            instructionAndPlayHolder.remove(headingLabel);
            instructionAndPlayHolder.remove(commandLabel);
            instructionAndPlayHolder.remove(checkedCommand);
            headingLabel = new Label(heading);
            headingLabel.get_style_context().add_class("heading");
            commandLabel = new Label("PRESS: " + keyspec.format_spec_display(command));
            descriptionLabel = new Label(description);
            createInstructionBox();
            demo = workflow.load_image(image);
            demo_box.add(demo);
            play_button.get_style_context().add_class("playButton");
            play_button.set_label("PLAY");
            isPlayed = false;
            instructionAndPlayHolder.reorder_child(buttonHolder, 3);
            this.show_all();
        }

        /**
         * Reads one step. Tolerant by design: these files come from distro
         * maintainers and the marketplace, so an unrecognised field is far more
         * likely to mean "newer schema" than "broken", and must not cost the user
         * the whole step. "function" is the pre-1 name for "description".
         */
        public void process_workflow_sequence(Json.Object obj) {
            command = ""; heading = ""; description = ""; image = "";

            foreach (unowned string name in obj.get_members()) {
                switch (name) {
                    case "key_id":      command     = step_string(obj, name); break;
                    case "heading":     heading     = step_string(obj, name); break;
                    case "description":
                    case "function":    description = step_string(obj, name); break;
                    case "image":       image       = step_string(obj, name); break;
                    default:
                        warning("%s: ignoring unknown step field \"%s\"", workflow.source, name);
                        break;
                }
            }
        }

        private string step_string(Json.Object obj, string name) {
            var node = obj.get_member(name);
            if (node == null || node.get_node_type() != Json.NodeType.VALUE) {
                warning("%s: step field \"%s\" is not a string", workflow.source, name);
                return "";
            }
            return obj.get_string_member(name) ?? "";
        }

        public void createInstructionBox() {
            instructionAndPlayHolder.get_style_context().add_class("commandDetailHolder");
            instructionAndPlayHolder.add(headingLabel);
            instructionAndPlayHolder.add(descriptionLabel);
            checkedCommand = new Box(Gtk.Orientation.HORIZONTAL, 20);
            checkTicked = new Gtk.Image.from_resource(APP_PATH + "/images/checktick.gif");
            checkedCommand.add(commandLabel);
            instructionAndPlayHolder.add(checkedCommand);
            checkedCommand.set_halign(Gtk.Align.CENTER);
        }

        public void handleTick() {
            checkTicked.opacity = 1.0;
        }
    }
}
