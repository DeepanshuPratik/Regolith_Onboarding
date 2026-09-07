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
     * This page also draws the click-to-continue prompt. The observer can only
     * report that its grab has gone deaf (needs_user_focus); what the user sees
     * and clicks is presentation, so it belongs here.
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

        /**
         * The demo slot, in pixels, and it is fixed on purpose.
         *
         * Assets are whatever size their author made them — the shipped set runs
         * from 500x346 to 1600x900 — so a slot that took each one's natural size
         * made every step a different shape and the window resized under the
         * user as they worked through a workflow. The slot is now constant and
         * the asset is fitted into it.
         */
        private const int DEMO_WIDTH  = 340;
        private const int DEMO_HEIGHT = 230;

        /**
         * The measure the step text wraps at. Without it a long description is a
         * single long line, which widens the page — the same resize by another
         * route.
         */
        private const int TEXT_WIDTH_CHARS = 46;

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
        // The click-to-continue prompt: hidden until the observer says its grab
        // has stopped receiving keys, which on GNOME is the ordinary case rather
        // than an edge one. Kept out of the instruction box on purpose — that
        // box is rebuilt and reordered by index between steps.
        private Gtk.Box focus_prompt;
        // A widget rather than a Gtk.Image: an animated asset is its own widget
        // that plays, and a still one is an Image. The page only ever adds and
        // removes it, so it does not care which it has.
        private Gtk.Widget demo;
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
            // FILL across, centred down the page. Centring horizontally left the
            // page at its natural width inside a wider window, which is the
            // band of empty space either side of the content on GNOME — where
            // the window is a normal toplevel and does not shrink to its
            // content the way a layer surface does.
            this.set_valign(Gtk.Align.CENTER);
            this.set_halign(Gtk.Align.FILL);
            this.hexpand = true;
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
            wrap_step_text ();
            instructionAndPlayHolder = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
            instructionAndPlayHolder.set_valign(Gtk.Align.CENTER);
            createInstructionBox();
            midBox = new Box(Gtk.Orientation.HORIZONTAL, 20);
            midBox.get_style_context().add_class("contentHolder");

            demo = workflow.load_demo(image, DEMO_WIDTH, DEMO_HEIGHT);
            demo_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 5);
            // The slot keeps its size whether the step has an asset or not, so
            // a step without one does not reflow the page.
            demo_box.set_size_request(DEMO_WIDTH, DEMO_HEIGHT);
            demo_box.set_valign(Gtk.Align.CENTER);
            demo_box.add(demo);
            midBox.add(instructionAndPlayHolder);
            midBox.add(demo_box);
            this.add(midBox);

            focus_prompt = build_focus_prompt ();
            this.add (focus_prompt);

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
            // The slot is a fixed size so the page does not change shape between
            // steps — but practice takes the demo away, and a slot still holding
            // 340x230 for a widget that is gone is a rectangle of nothing in the
            // middle of the shrunken card. Give the space back until the next
            // step needs it.
            demo_box.set_size_request(-1, -1);
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
                practice.needs_user_focus.connect (on_needs_user_focus);
                capture_started = true;

                if (!practice.start ())
                    stderr.printf ("Nothing here can observe the keypress; this step cannot complete.\n");
            }

            hide_focus_prompt ();
            practice.arm (command);
            this.show_all();
        }

        /**
         * The observer's grab has stopped receiving keys and only the user can
         * fix it: on GNOME the app cannot take focus back at all (#11), so the
         * recovery path is them clicking into this window. Until they do, the
         * step they are being asked to perform cannot complete, and without this
         * prompt it simply appears to stop responding.
         */
        private void on_needs_user_focus () {
            // Nothing is armed before PLAY, and after a match the step is over;
            // a prompt in either case would be asking the user to rescue a grab
            // nobody is waiting on.
            if (!isPlayed) return;

            focus_prompt.no_show_all = false;
            focus_prompt.show_all ();
        }

        /**
         * Their click has already brought focus back — that is what a click on
         * this button means. Telling the session lets the observer re-arm its
         * timeout, so a second loss of focus prompts again.
         */
        private void on_user_returned () {
            hide_focus_prompt ();
            practice.user_returned ();
        }

        private void hide_focus_prompt () {
            focus_prompt.hide ();
            // Back on, or the next show_all() on the page reveals it again.
            focus_prompt.no_show_all = true;
        }

        /**
         * no_show_all because this page calls show_all() after nearly every
         * change, and the prompt must appear only when the observer asks for it.
         * That also means show_all() on the box itself is a no-op, so
         * on_needs_user_focus clears the flag first.
         */
        private Gtk.Box build_focus_prompt () {
            var box = new Box (Gtk.Orientation.VERTICAL, 8);
            box.get_style_context ().add_class ("focus-prompt");
            box.set_halign (Gtk.Align.CENTER);

            var explanation = new Label (
                "Another window has the keyboard, so the shortcut you press cannot reach this step.");
            explanation.set_line_wrap (true);
            // GTK CSS has no max-width, so the measure is set here rather than
            // in flow.css, where it would be a parse error in the log.
            explanation.max_width_chars = 44;
            explanation.set_justify (Gtk.Justification.CENTER);
            explanation.get_style_context ().add_class ("focus-prompt-text");

            var resume_button = new Button.with_label ("CLICK HERE TO CONTINUE");
            resume_button.get_style_context ().add_class ("playButton");
            resume_button.clicked.connect (on_user_returned);

            box.add (explanation);
            box.add (resume_button);
            box.no_show_all = true;
            return box;
        }

        // The user pressed the right key: perform the real action, confirm it, and
        // move on after a beat so the tick is actually seen.
        private void on_step_matched () {
            hide_focus_prompt ();
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
                practice.needs_user_focus.disconnect (on_needs_user_focus);
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
            wrap_step_text ();
            createInstructionBox();
            demo = workflow.load_demo(image, DEMO_WIDTH, DEMO_HEIGHT);
            demo_box.set_size_request(DEMO_WIDTH, DEMO_HEIGHT);
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

        /**
         * Holds the step text to a measure. GTK CSS has no max-width, so this is
         * the only place it can be said — and without it the page is as wide as
         * its longest description, which differs per step.
         */
        private void wrap_step_text () {
            Label[] wrapped = { headingLabel, descriptionLabel };
            foreach (var label in wrapped) {
                label.set_line_wrap (true);
                label.max_width_chars = TEXT_WIDTH_CHARS;
                label.set_justify (Gtk.Justification.CENTER);
            }

            // The shortcut itself never wraps. On the shrunken practice card
            // there is less width than this label wants, and wrapping it put
            // "Super +" on one line and "V" on the next — the one string on the
            // page that has to be readable at a glance, broken in half. Letting
            // it set the card's minimum width is the right trade.
            commandLabel.set_line_wrap (false);
            commandLabel.set_justify (Gtk.Justification.CENTER);

            // flow.css and theme.css have carried styles for these three since
            // before this page existed, and the page never applied them — so the
            // step's own text was the only thing on a dark card wearing the GTK
            // theme's default label colour, which is nearly illegible on it.
            // .text-secondary and .practice-command are both in the documented
            // styling contract, so a distro can already reach them.
            descriptionLabel.get_style_context ().add_class ("practice-description");
            descriptionLabel.get_style_context ().add_class ("text-secondary");
            commandLabel.get_style_context ().add_class ("practice-command");
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
