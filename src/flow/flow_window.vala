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

namespace regolith_onboarding {

    public class WorkFlowPage : Box {

        public delegate void workflowList();

        // variables for holding json data to be displayed
        private string heading = "";
        private string command = " ";
        private string description = " ";
        private string image = "";
        private string execCommand = "";

        // window positions
        private int curr_x = 0;
        private int curr_y = 0;

        // Json iterator
        private uint current_key_sequence = 0;
        private bool isPlayed = false;
        private Gtk.Button play_button;
        private KeybindingsHandler keypressHandler;
        private Gtk.Image demo;
        private Gtk.Box demo_box;
        private Gtk.Button cancel_button;
        private Gtk.Box checkedCommand;
        private Gtk.Image checkTicked;
        private string mode = "";

        // WM mode fields.
        // The mode block (like "Resize Mode") is written into the active sway config
        // via the user's config.d directory, which is included by:
        //   include $HOME/.config/regolith3/sway/config.d/*
        // Keypresses are detected via sway IPC binding-event subscription (no FIFO).
        private const string WM_MODE_NAME = "Onboarding";
        private bool   use_wm_mode  = false;
        private string mode_file_path = "";   // path of the config.d file we created
        // swaymsg -t subscribe -m process
        private Pid            ipc_pid      = 0;
        private GLib.IOChannel ipc_channel  = null;
        private uint           ipc_watch_id = 0;

        // UI components
        private Gtk.Box midBox;
        private Gtk.Box instructionAndPlayHolder;
        private Label headingLabel;
        private Label commandLabel;
        private Label descriptionLabel;

        public WorkFlowPage(Json.Array? key_binding_info, owned workflowList workflowList) {
            Object(orientation: Gtk.Orientation.VERTICAL, spacing: 10);
            this.margin = 20;
            this.set_valign(Gtk.Align.CENTER);
            this.set_halign(Gtk.Align.CENTER);
            this.get_style_context().add_class("practice-page");

            var css_provider = new Gtk.CssProvider();
            css_provider.load_from_resource(APP_PATH + "/css/flow.css");
            Gtk.StyleContext.add_provider_for_screen(this.get_screen(), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);

            var buttonHolder = new Box(Gtk.Orientation.HORIZONTAL, 2);
            keypressHandler = new KeybindingsHandler();
            var configmanager = new configManager();

            if (key_binding_info != null) {
                Json.Object obj = key_binding_info.get_element(current_key_sequence).get_object();
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

                string image_path_from_json = image;
                demo = new Gtk.Image.from_resource(APP_PATH + "/" + image_path_from_json);
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

                // ── Fallback: GTK key-press handler used when WM-mode setup fails ──
                // Guarded by !use_wm_mode so it is inactive when the IPC path is live.
                key_press_event.connect((key) => {
                    if (use_wm_mode) return false;
                    if (mode != "TILEUP") return false;
                    var fmt = configmanager.format_spec(command);
                    string[] tokens = fmt.split(" ");
                    uint COMMAND_MASK = 0;
                    uint token_count = tokens.length;
                    for (int i = 0; i < tokens.length - 1; i++)
                        COMMAND_MASK |= keypressHandler.modifierMasks[tokens[i]];
                    bool matched = false;
                    if (keypressHandler.nonModifiers.get(tokens[token_count - 1]) != (uint)null)
                        matched = keypressHandler.match(key, COMMAND_MASK, keypressHandler.nonModifiers[tokens[token_count - 1]], true);
                    else
                        matched = keypressHandler.match(key, COMMAND_MASK, (uint)tokens[token_count - 1][0], false);
                    if (matched) {
                        COMMAND_MASK = 0;
                        current_key_sequence++;
                        regolith_onboarding.seat.ungrab();
                        Posix.system(execCommand);
                        handleTick();
                        Gdk.Window gdkwin = this.get_window();
                        regolith_onboarding.seat.grab(gdkwin, Gdk.SeatCapabilities.KEYBOARD | Gdk.SeatCapabilities.POINTER, true, null, null, null);
                        this.show_all();
                        GLib.Timeout.add_seconds(2, () => {
                            var window = (Gtk.Window) this.get_toplevel();
                            new HandleScreenMode(window, "WINDOW", curr_x, curr_y);
                            mode = "WINDOW";
                            if (current_key_sequence >= key_binding_info.get_length()) {
                                if (IS_SESSION_WAYLAND) regolith_onboarding.seat.ungrab();
                                workflowList();
                                this.destroy();
                            }
                            obj = key_binding_info.get_element(current_key_sequence).get_object();
                            try {
                                process_workflow_sequence(obj);
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
                                commandLabel = new Label("PRESS: " + configmanager.format_spec_display(command));
                                descriptionLabel = new Label(description);
                                createInstructionBox();
                                image_path_from_json = image;
                                demo = new Gtk.Image.from_resource(APP_PATH + "/" + image_path_from_json);
                                demo_box.add(demo);
                                play_button.get_style_context().add_class("playButton");
                                play_button.set_label("PLAY");
                                isPlayed = false;
                                instructionAndPlayHolder.reorder_child(buttonHolder, 3);
                                this.show_all();
                            } catch (Error e) {
                                stderr.printf("Error in fallback step advance: %s\n", e.message);
                            }
                            return false;
                        });
                    }
                    stdout.flush();
                    return false;
                });

                // ── PLAY button ──
                play_button.clicked.connect(() => {
                    if (!isPlayed) {
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
                        execCommandString();
                        play_button.set_label("CAPTURING");

                        if (use_wm_mode) {
                            // Mode already set up — re-enter it for the next step.
                            var wm_cmd = (WM_NAME == "sway") ? "swaymsg" : "i3-msg";
                            stdout.printf("[WM MODE] Re-entering mode '%s'\n", WM_MODE_NAME);
                            try {
                                Process.spawn_command_line_sync(wm_cmd + " mode '" + WM_MODE_NAME + "'");
                            } catch (Error e) {
                                stderr.printf("[WM MODE] Failed to re-enter mode: %s\n", e.message);
                            }
                        } else if (setup_wm_mode(key_binding_info)) {
                            // First PLAY press: mode file written, swaymsg subscribed.
                            use_wm_mode = true;

                            // ── IPC binding-event watcher (replaces key_press_event) ──
                            ipc_watch_id = ipc_channel.add_watch(
                                GLib.IOCondition.IN | GLib.IOCondition.HUP,
                                (src, cond) => {
                                    if ((cond & GLib.IOCondition.HUP) != 0) {
                                        stdout.printf("[WM MODE] IPC channel closed (HUP)\n");
                                        return false;
                                    }
                                    try {
                                        string line;
                                        size_t length, term_pos;
                                        if (src.read_line(out line, out length, out term_pos) != GLib.IOStatus.NORMAL)
                                            return true;
                                        if (line == null) return true;
                                        line = line.strip();
                                        if (line.length == 0) return true;

                                        stdout.printf("[WM MODE] IPC raw line: %s\n", line);
                                        stdout.flush();

                                        // Skip subscription acknowledgement: [{"success":true}]
                                        if (line.has_prefix("[")) {
                                            stdout.printf("[WM MODE] Skipping subscription ack\n");
                                            return true;
                                        }

                                        // Only act while actively capturing a step
                                        if (mode != "TILEUP") {
                                            stdout.printf("[WM MODE] Ignoring event (mode=%s, not TILEUP)\n", mode);
                                            return true;
                                        }

                                        // Parse the binding event JSON
                                        var parser = new Json.Parser();
                                        parser.load_from_data(line);
                                        var root_obj = parser.get_root().get_object();
                                        var change = root_obj.get_string_member("change");
                                        stdout.printf("[WM MODE] Event change type: %s\n", change);
                                        if (change != "run") return true;

                                        var bnd = root_obj.get_object_member("binding");

                                        // symbol can be null for bindcode bindings — skip those
                                        var sym_node = bnd.get_member("symbol");
                                        if (sym_node == null || sym_node.is_null()) {
                                            stdout.printf("[WM MODE] Skipping event: no symbol (bindcode binding)\n");
                                            return true;
                                        }
                                        var symbol = sym_node.get_string();
                                        var mask_arr = bnd.get_array_member("event_state_mask");

                                        // Build a human-readable modifier string for logging
                                        var sb = new StringBuilder();
                                        for (uint mi = 0; mi < mask_arr.get_length(); mi++) {
                                            if (mi > 0) sb.append("+");
                                            sb.append(mask_arr.get_element(mi).get_string());
                                        }
                                        string mods_str = sb.str.length > 0 ? sb.str : "(none)";

                                        // Combine modifiers + symbol into one readable string
                                        string pressed = (mask_arr.get_length() > 0)
                                            ? mods_str + "+" + symbol
                                            : symbol;

                                        stdout.printf("[WM MODE] ── Key Event Received ──────────────────\n");
                                        stdout.printf("[WM MODE]   PRESSED      : %s\n", pressed);
                                        stdout.printf("[WM MODE]   symbol       : %s\n", symbol);
                                        stdout.printf("[WM MODE]   modifiers    : %s\n", mods_str);

                                        // What we expect for the current step
                                        var cfg = new configManager();
                                        var expected = cfg.format_spec_for_mode(command);
                                        stdout.printf("[WM MODE]   raw command  : %s\n", command);
                                        stdout.printf("[WM MODE]   expected key : %s\n", expected.length > 0 ? expected : "(opaque id — skip)");
                                        stdout.printf("[WM MODE]   exec command : %s\n", execCommand);

                                        // Escape → cancel the workflow
                                        if (symbol == "Escape") {
                                            stdout.printf("[WM MODE] Escape pressed — cancelling workflow\n");
                                            teardown_wm_mode();
                                            var win = (Gtk.Window) this.get_toplevel();
                                            new HandleScreenMode(win, "WINDOW", curr_x, curr_y);
                                            mode = "WINDOW";
                                            workflowList();
                                            this.destroy();
                                            return false;
                                        }

                                        if (expected == "") {
                                            stdout.printf("[WM MODE]   → Opaque key_id, cannot match — skipping\n");
                                            return true;
                                        }

                                        bool matched = ipc_event_matches(expected, symbol, mask_arr);
                                        stdout.printf("[WM MODE]   → Match: %s\n", matched ? "YES ✓" : "NO ✗");
                                        stdout.printf("[WM MODE] ────────────────────────────────────────\n");
                                        stdout.flush();

                                        if (matched) {
                                            // Set mode immediately so the IPC guard at the top
                                            // of this handler blocks re-matches while the
                                            // 2s tick-display timeout is pending.
                                            mode = "WINDOW";

                                            var wm_cmd_l = (WM_NAME == "sway") ? "swaymsg" : "i3-msg";
                                            current_key_sequence++;

                                            // Exit mode so the simulated keypress goes to the WM
                                            try { Process.spawn_command_line_sync(wm_cmd_l + " mode default"); } catch {}
                                            stdout.printf("[WM MODE] Executing: %s\n", execCommand);
                                            Posix.system(execCommand);

                                            handleTick();
                                            this.show_all();

                                            GLib.Timeout.add_seconds(2, () => {
                                                // Guard: widget may have been reparented or destroyed
                                                var toplevel = this.get_toplevel();
                                                if (!(toplevel is Gtk.Window)) return false;
                                                var win = (Gtk.Window) toplevel;
                                                new HandleScreenMode(win, "WINDOW", curr_x, curr_y);

                                                if (current_key_sequence >= key_binding_info.get_length()) {
                                                    stdout.printf("[WM MODE] Workflow complete — tearing down\n");
                                                    teardown_wm_mode();
                                                    workflowList();
                                                    this.destroy();
                                                    return false;
                                                }

                                                obj = key_binding_info.get_element(current_key_sequence).get_object();
                                                try {
                                                    process_workflow_sequence(obj);
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
                                                    image_path_from_json = image;
                                                    demo = new Gtk.Image.from_resource(APP_PATH + "/" + image_path_from_json);
                                                    demo_box.add(demo);
                                                    play_button.get_style_context().add_class("playButton");
                                                    play_button.set_label("PLAY");
                                                    isPlayed = false;
                                                    instructionAndPlayHolder.reorder_child(buttonHolder, 3);
                                                    execCommandString();
                                                    this.show_all();
                                                } catch (Error e) {
                                                    stderr.printf("Error advancing step: %s\n", e.message);
                                                }
                                                return false;
                                            });
                                        }
                                    } catch (Error e) {
                                        stderr.printf("[WM MODE] IPC event error: %s\n", e.message);
                                    }
                                    return true;
                                });
                        } else {
                            // WM mode unavailable: fall back to seat.grab (X11/unknown WM).
                            stderr.printf("[WM MODE] setup_wm_mode() failed — falling back to seat.grab / X11 input capture\n");
                            use_wm_mode = false;
                            if (IS_SESSION_WAYLAND) {
                                var gdkwin = this.get_window();
                                if (gdkwin != null) {
                                    var grabbed = grab_inputs(gdkwin);
                                    if (grabbed != null)
                                        regolith_onboarding.seat = grabbed;
                                    else
                                        stderr.printf("Failed to grab input devices.\n");
                                }
                            }
                        }
                        this.show_all();
                    }
                });

                // ── CANCEL button ──
                cancel_button.clicked.connect(() => {
                    if (use_wm_mode) {
                        teardown_wm_mode();
                    } else if (IS_SESSION_WAYLAND) {
                        regolith_onboarding.seat.ungrab();
                    }
                    var window = (Gtk.Window) this.get_toplevel();
                    if (curr_x == 0 && curr_y == 0)
                        window.get_position(out curr_x, out curr_y);
                    new HandleScreenMode(window, "WINDOW", curr_x, curr_y);
                    mode = "WINDOW";
                    workflowList();
                    this.destroy();
                });
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // WM Mode setup
        // ─────────────────────────────────────────────────────────────────────

        // Writes a mode block to the user's sway config.d directory (which is
        // auto-included by the active Regolith sway config via
        //   include $HOME/.config/regolith3/sway/config.d/*
        // This is the same mechanism used by resize mode, session mode, etc.).
        // Then reloads the WM, starts an IPC subscription for binding events,
        // and enters the mode so the bar shows "Onboarding".
        // Returns true on success; caller falls back to seat.grab on false.
        private bool setup_wm_mode(Json.Array key_binding_info) {
            if (WM_NAME != "sway" && WM_NAME != "i3") {
                stderr.printf("[WM MODE] Unsupported WM '%s' — falling back to seat.grab\n", WM_NAME);
                return false;
            }

            var wm_cmd = (WM_NAME == "sway") ? "swaymsg" : "i3-msg";
            var cfg = new configManager();

            // ── 1. Find the config.d directory ──
            var config_d = find_or_create_config_d();
            if (config_d == null) {
                stderr.printf("[WM MODE] setup_wm_mode: config.d directory unavailable — cannot write mode file\n");
                return false;
            }
            mode_file_path = Path.build_filename(config_d, "regolith_onboarding_mode");

            // ── 2. Build and log the mode block we are about to write ──
            var sb = new StringBuilder();
            sb.append("mode \"" + WM_MODE_NAME + "\" {\n");
            int binding_count = 0;
            for (int i = 0; i < (int)key_binding_info.get_length(); i++) {
                try {
                    var element = key_binding_info.get_element(i);
                    if (element == null || element.get_node_type() != Json.NodeType.OBJECT) {
                        stderr.printf("[WM MODE]   entry %d: expected JSON object, got %s — skipping\n",
                                      i, element != null ? element.type_name() : "null");
                        continue;
                    }
                    var obj = element.get_object();
                    if (!obj.has_member("key_id")) {
                        stderr.printf("[WM MODE]   entry %d: missing 'key_id' field — skipping\n", i);
                        continue;
                    }
                    var key_id = obj.get_string_member("key_id");
                    var wm_key = cfg.format_spec_for_mode(key_id);
                    if (wm_key == "") {
                        stdout.printf("[WM MODE]   skipping opaque key_id: %s\n", key_id);
                        continue;
                    }
                    sb.append("    bindsym " + wm_key + " nop\n");
                    binding_count++;
                } catch (Error e) {
                    stderr.printf("[WM MODE]   entry %d: error reading key binding info: %s — skipping\n", i, e.message);
                }
            }
            if (binding_count == 0) {
                stderr.printf("[WM MODE]   WARNING: no valid keybindings produced — mode block will only contain Escape\n");
            }
            sb.append("    bindsym Escape nop\n");
            sb.append("}\n");
            string mode_block = sb.str;

            stdout.printf("\n[WM MODE] ════════════════════════════════════════\n");
            stdout.printf("[WM MODE] Writing mode block to ACTIVE sway config\n");
            stdout.printf("[WM MODE] Config include path : include %s/*\n", config_d);
            stdout.printf("[WM MODE] Mode file           : %s\n", mode_file_path);
            stdout.printf("[WM MODE] %d keybinding(s) + Escape defined\n", binding_count);
            stdout.printf("[WM MODE] ── Mode block content ──────────────────\n");
            stdout.printf("%s", mode_block);
            stdout.printf("[WM MODE] ─────────────────────────────────────────\n");
            stdout.flush();

            // ── 3. Write the mode file ──
            try {
                var f = File.new_for_path(mode_file_path);
                var w = new DataOutputStream(f.replace(null, false, FileCreateFlags.NONE));
                w.put_string(mode_block);
                w.close();
                stdout.printf("[WM MODE] File written successfully\n");
            } catch (Error e) {
                stderr.printf("[WM MODE] Failed to write mode file: %s\n", e.message);
                return false;
            }

            // ── 4. Reload WM so the mode definition is picked up ──
            stdout.printf("[WM MODE] Reloading %s to register the mode...\n", wm_cmd);
            try {
                Process.spawn_command_line_sync(wm_cmd + " reload");
                stdout.printf("[WM MODE] Reload OK\n");
            } catch (Error e) {
                stderr.printf("[WM MODE] Reload failed: %s\n", e.message);
                cleanup_mode_file();
                return false;
            }

            // Small delay so sway finishes processing the reload before we
            // enter the mode and subscribe — avoids a race where the mode
            // definition isn't registered yet.
            GLib.Thread.usleep (200 * 1000);  // 200 ms

            // ── 5. Subscribe to IPC binding events ──
            stdout.printf("[WM MODE] Subscribing to sway IPC binding events...\n");
            try {
                int stdout_fd;
                string[] argv = {wm_cmd, "-t", "subscribe", "-m", "[\"binding\"]"};
                Process.spawn_async_with_pipes(
                    null, argv, null,
                    SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                    null, out ipc_pid, null, out stdout_fd, null);
                ipc_channel = new GLib.IOChannel.unix_new(stdout_fd);
                stdout.printf("[WM MODE] IPC subscriber running (pid %d)\n", (int)ipc_pid);
            } catch (Error e) {
                stderr.printf("[WM MODE] IPC subscribe failed: %s\n", e.message);
                cleanup_mode_file();
                return false;
            }

            // ── 6. Enter the mode (bar will now show "Onboarding") ──
            stdout.printf("[WM MODE] Entering mode '%s'...\n", WM_MODE_NAME);
            try {
                Process.spawn_command_line_sync(wm_cmd + " mode '" + WM_MODE_NAME + "'");
                stdout.printf("[WM MODE] Mode '%s' active — bar should now show the mode name\n", WM_MODE_NAME);
            } catch (Error e) {
                stderr.printf("[WM MODE] Failed to enter mode: %s\n", e.message);
                teardown_wm_mode();
                return false;
            }

            stdout.printf("[WM MODE] Setup complete\n");
            stdout.printf("[WM MODE] ════════════════════════════════════════\n\n");
            stdout.flush();
            return true;
        }

        // Exits the mode, stops the IPC subscription, and removes the mode file.
        private void teardown_wm_mode() {
            var wm_cmd = (WM_NAME == "sway") ? "swaymsg" : "i3-msg";
            stdout.printf("[WM MODE] Tearing down mode '%s'...\n", WM_MODE_NAME);
            try { Process.spawn_command_line_sync(wm_cmd + " mode default"); } catch {}

            if (ipc_watch_id != 0) {
                GLib.Source.remove(ipc_watch_id);
                ipc_watch_id = 0;
            }
            if (ipc_channel != null) {
                try { ipc_channel.shutdown(false); } catch {}
                ipc_channel = null;
            }
            if (ipc_pid != 0) {
                Posix.kill((Posix.pid_t)ipc_pid, Posix.Signal.TERM);
                ChildWatch.add(ipc_pid, (pid, status) => { Process.close_pid(pid); });
                ipc_pid = 0;
            }

            cleanup_mode_file();
            use_wm_mode = false;
            stdout.printf("[WM MODE] Teardown complete\n");
        }

        private void cleanup_mode_file() {
            if (mode_file_path == "") return;
            var wm_cmd = (WM_NAME == "sway") ? "swaymsg" : "i3-msg";
            stdout.printf("[WM MODE] Deleting mode file: %s\n", mode_file_path);
            try { File.new_for_path(mode_file_path).delete(); } catch {}
            mode_file_path = "";
            stdout.printf("[WM MODE] Reloading %s to remove the mode definition...\n", wm_cmd);
            try { Process.spawn_command_line_sync(wm_cmd + " reload"); } catch {}
        }

        // Returns the first existing config.d directory (Regolith-first order),
        // or creates the regolith3 one if none are found yet.
        private string? find_or_create_config_d() {
            string[] candidates = (WM_NAME == "sway") ? new string[]{
                Path.build_filename(Environment.get_home_dir(), ".config", "regolith3", "sway", "config.d"),
                Path.build_filename(Environment.get_home_dir(), ".config", "regolith2", "sway", "config.d"),
                Path.build_filename(Environment.get_home_dir(), ".config", "sway", "config.d"),
            } : new string[]{
                Path.build_filename(Environment.get_home_dir(), ".config", "regolith3", "i3", "config.d"),
                Path.build_filename(Environment.get_home_dir(), ".config", "regolith2", "i3", "config.d"),
                Path.build_filename(Environment.get_home_dir(), ".config", "i3", "config.d"),
            };
            foreach (var dir in candidates) {
                if (FileUtils.test(dir, FileTest.IS_DIR)) {
                    stdout.printf("[WM MODE] Using existing config.d: %s\n", dir);
                    return dir;
                }
            }
            try {
                File.new_for_path(candidates[0]).make_directory_with_parents();
                stdout.printf("[WM MODE] Created config.d: %s\n", candidates[0]);
                return candidates[0];
            } catch (Error e) {
                stderr.printf("[WM MODE] Cannot find or create config.d: %s\n", e.message);
                return null;
            }
        }

        // Returns true if the sway IPC binding event (symbol + modifier mask) matches
        // the expected key string from format_spec_for_mode, e.g. "Mod4+Return".
        private bool ipc_event_matches(string expected, string symbol, Json.Array mask_arr) {
            var parts = expected.split("+");
            // Last part is the key symbol; preceding parts are modifiers
            var expected_sym = parts[parts.length - 1];
            if (symbol != expected_sym) {
                stdout.printf("[WM MODE]   symbol mismatch: got '%s', want '%s'\n", symbol, expected_sym);
                return false;
            }

            int expected_mod_count = parts.length - 1;
            int actual_mod_count   = (int)mask_arr.get_length();
            if (expected_mod_count != actual_mod_count) {
                stdout.printf("[WM MODE]   modifier count mismatch: got %d, want %d\n",
                              actual_mod_count, expected_mod_count);
                return false;
            }

            // Case-insensitive modifier comparison ("Mod4" == "mod4" etc.)
            for (int i = 0; i < actual_mod_count; i++) {
                var actual_mod = mask_arr.get_element(i).get_string().down();
                bool found = false;
                for (int j = 0; j < expected_mod_count; j++) {
                    if (parts[j].down() == actual_mod) { found = true; break; }
                }
                if (!found) {
                    stdout.printf("[WM MODE]   modifier mismatch: '%s' not in expected set\n", actual_mod);
                    return false;
                }
            }
            return true;
        }

        // ─────────────────────────────────────────────────────────────────────
        // Existing helpers (unchanged)
        // ─────────────────────────────────────────────────────────────────────

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

        public void execCommandString() {
            var configmanager = new configManager();
            if (IS_SESSION_WAYLAND) {
                // Prefer ydotool (native Wayland); fall back to xdotool via XWayland.
                // Note: xdotool cannot trigger sway compositor bindings on Wayland,
                // but it avoids a hard "not found" error when ydotool is absent.
                string? ydotool_path = GLib.Environment.find_program_in_path ("ydotool");
                if (ydotool_path != null) {
                    execCommand = "ydotool key ";
                } else {
                    stdout.printf ("[WM MODE] ydotool not found — using xdotool (Wayland fallback)\n");
                    execCommand = "xdotool sleep 0.5 key --clearmodifiers ";
                }
            } else {
                execCommand = "xdotool sleep 0.5 key --clearmodifiers ";
            }
            string[] splitCommands = configmanager.format_spec(command).split(" ");
            for (int i = 0; i < splitCommands.length - 1; i++)
                execCommand += keypressHandler.remontoireSymToKey[splitCommands[i]] + "+";
            var last = splitCommands[splitCommands.length - 1];
            execCommand += (keypressHandler.remontoireSymToKey.get(last) != (string)null)
                ? keypressHandler.remontoireSymToKey[last]
                : last;
            stdout.printf ("[WM MODE] execCommand: %s\n", execCommand);
        }

        private Gdk.Seat? grab_inputs(Gdk.Window gdkwin) {
            var display = gdkwin.get_display();
            if (display == null) { stderr.printf("Failed to get Display\n"); return null; }
            var seat = display.get_default_seat();
            if (seat == null) { stdout.printf("Failed to get Seat\n"); return null; }

            int attempt = 0;
            Gdk.GrabStatus? grabStatus = null;
            int wait_time = 1000;
            do {
                grabStatus = seat.grab(gdkwin, Gdk.SeatCapabilities.KEYBOARD | Gdk.SeatCapabilities.POINTER, true, null, null, null);
                if (grabStatus != Gdk.GrabStatus.SUCCESS) {
                    attempt++;
                    wait_time *= 2;
                    GLib.Thread.usleep(wait_time);
                }
            } while (grabStatus != Gdk.GrabStatus.SUCCESS && attempt < 8);

            if (grabStatus != Gdk.GrabStatus.SUCCESS) {
                stderr.printf("Failed to grab input: %d\n", grabStatus);
                return null;
            }
            return seat;
        }
    }
}
