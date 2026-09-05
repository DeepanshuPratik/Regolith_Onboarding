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
     * was actually pressed, and performing the action it is normally bound to, are
     * delegated to a CaptureBackend chosen for the running desktop.
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

        private int curr_x = 0;
        private int curr_y = 0;

        private uint current_key_sequence = 0;
        private bool isPlayed = false;
        private string mode = "";

        private Json.Array? steps;
        private CaptureBackend capture;
        private KeySynthesizer synth = new KeySynthesizer ();
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

        public WorkFlowPage(Json.Array? key_binding_info, owned workflowList workflowList) {
            Object(orientation: Gtk.Orientation.VERTICAL, spacing: 10);
            this.margin = 20;
            this.set_valign(Gtk.Align.CENTER);
            this.set_halign(Gtk.Align.CENTER);
            this.get_style_context().add_class("practice-page");

            this.steps = key_binding_info;
            this.return_to_list = (owned) workflowList;

            var css_provider = new Gtk.CssProvider();
            css_provider.load_from_resource(APP_PATH + "/css/flow.css");
            Gtk.StyleContext.add_provider_for_screen(this.get_screen(), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);

            if (steps == null) return;

            buttonHolder = new Box(Gtk.Orientation.HORIZONTAL, 2);
            var configmanager = new configManager();

            Json.Object obj = steps.get_element(current_key_sequence).get_object();
            try {
                process_workflow_sequence(obj);
            } catch (Error e) {
                stderr.printf("Error in process_workflow_sequence: %s\n", e.message);
            }

            headingLabel = new Label(heading);
            commandLabel = new Label("PRESS: " + configmanager.format_spec_display(command));
            headingLabel.get_style_context().add_class("heading");
            descriptionLabel = new Label(description);
            instructionAndPlayHolder = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
            instructionAndPlayHolder.set_valign(Gtk.Align.CENTER);
            createInstructionBox();
            midBox = new Box(Gtk.Orientation.HORIZONTAL, 20);
            midBox.get_style_context().add_class("contentHolder");

            demo = new Gtk.Image.from_resource(APP_PATH + "/" + image);
            demo_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 5);
            demo_box.add(demo);
            midBox.add(instructionAndPlayHolder);
            midBox.add(demo_box);
            this.add(midBox);

            cancel_button = new Gtk.Button();
            cancel_button.get_style_context().add_class("cancelButton");
            cancel_button.set_label("CANCEL");
            play_button = new Button();
            play_button.get_style_context().add_class("playButton");
            play_button.set_label("PLAY");
            buttonHolder.add(play_button);
            buttonHolder.add(cancel_button);
            buttonHolder.expand = false;
            buttonHolder.set_halign(Gtk.Align.CENTER);
            instructionAndPlayHolder.add(buttonHolder);

            capture = CaptureBackends.for_session (this);
            capture.step_matched.connect (on_step_matched);
            capture.aborted.connect (on_aborted);

            play_button.clicked.connect (on_play);
            cancel_button.clicked.connect (on_cancel);
        }

        // PLAY shrinks the window out of the way and hands control to the backend
        // so the user can perform the shortcut against their real desktop.
        private void on_play () {
            if (isPlayed) return;

            var window = (Gtk.Window) this.get_toplevel();
            if (curr_x == 0 && curr_y == 0)
                window.get_position(out curr_x, out curr_y);
            new HandleScreenMode(window, "TILEUP", curr_x, curr_y);
            mode = "TILEUP";

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
                if (!capture.start (steps)) {
                    stderr.printf ("%s failed to start — falling back to seat grab\n",
                                   capture.get_type ().name ());
                    capture = CaptureBackends.fallback (this);
                    capture.step_matched.connect (on_step_matched);
                    capture.aborted.connect (on_aborted);
                    capture.start (steps);
                }
                capture_started = true;
            }

            capture.arm (command);
            this.show_all();
        }

        // The user pressed the right key: perform the real action, confirm it, and
        // move on after a beat so the tick is actually seen.
        private void on_step_matched () {
            current_key_sequence++;
            capture.dispatch (command, synth.command_for (command));
            handleTick();
            this.show_all();

            GLib.Timeout.add_seconds (STEP_ADVANCE_DELAY_SECONDS, () => {
                var toplevel = this.get_toplevel();
                if (!(toplevel is Gtk.Window)) return false;
                new HandleScreenMode((Gtk.Window) toplevel, "WINDOW", curr_x, curr_y);
                mode = "WINDOW";

                if (current_key_sequence >= steps.get_length()) {
                    finish ();
                    return false;
                }

                try {
                    reset_ui_for_next_step (steps.get_element(current_key_sequence).get_object());
                } catch (Error e) {
                    stderr.printf("Error advancing step: %s\n", e.message);
                }
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
            var window = (Gtk.Window) this.get_toplevel();
            if (curr_x == 0 && curr_y == 0)
                window.get_position(out curr_x, out curr_y);
            new HandleScreenMode(window, "WINDOW", curr_x, curr_y);
            mode = "WINDOW";
        }

        private void finish () {
            capture.stop ();
            return_to_list ();
            this.destroy();
        }

        // Resets all UI labels/images after a step completes and loads the next one.
        private void reset_ui_for_next_step(Json.Object next_obj) throws Error {
            var cfg = new configManager();
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
            commandLabel = new Label("PRESS: " + cfg.format_spec_display(command));
            descriptionLabel = new Label(description);
            createInstructionBox();
            demo = new Gtk.Image.from_resource(APP_PATH + "/" + image);
            demo_box.add(demo);
            play_button.get_style_context().add_class("playButton");
            play_button.set_label("PLAY");
            isPlayed = false;
            instructionAndPlayHolder.reorder_child(buttonHolder, 3);
            this.show_all();
        }

        public void process_workflow_sequence(Json.Object obj) throws Error {
            foreach (unowned string name in obj.get_members()) {
                switch (name) {
                    case "key_id":
                        if (obj.get_member(name).get_node_type() != Json.NodeType.VALUE)
                            throw new MyError.INVALID_FORMAT("Bad type for key_id");
                        command = obj.get_string_member(name);
                        break;
                    case "function":
                        if (obj.get_member(name).get_node_type() != Json.NodeType.VALUE)
                            throw new MyError.INVALID_FORMAT("Bad type for function");
                        description = obj.get_string_member(name);
                        break;
                    case "heading":
                        if (obj.get_member(name).get_node_type() != Json.NodeType.VALUE)
                            throw new MyError.INVALID_FORMAT("Bad type for heading");
                        heading = obj.get_string_member(name);
                        break;
                    case "image":
                        if (obj.get_member(name).get_node_type() != Json.NodeType.VALUE)
                            throw new MyError.INVALID_FORMAT("Bad type for image");
                        image = obj.get_string_member(name);
                        break;
                    default:
                        throw new MyError.INVALID_FORMAT("Unexpected element '%s'", name);
                }
            }
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
