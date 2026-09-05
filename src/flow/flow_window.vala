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

    public class WorkFlowPage : Box {

        public delegate void workflowList();

        private string heading = "";
        private string command = " ";
        private string description = " ";
        private string image = "";
        private string execCommand = "";

        private int curr_x = 0;
        private int curr_y = 0;

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

        // Sway/i3 mode block written to config.d for keybinding interception.
        // Keypresses are detected via IPC binding-event subscription (no seat grab needed).
        private const string WM_MODE_NAME = "Onboarding";
        private bool   use_wm_mode  = false;
        private string mode_file_path = "";
        private Pid            ipc_pid      = 0;
        private GLib.IOChannel ipc_channel  = null;
        private uint           ipc_watch_id = 0;

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

                // Fallback GTK key handler — only active when WM mode setup fails (X11/unknown WM).
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
                        linux_onboarding.seat.ungrab();
                        Posix.system(execCommand);
                        handleTick();
                        Gdk.Window gdkwin = this.get_window();
                        linux_onboarding.seat.grab(gdkwin, Gdk.SeatCapabilities.KEYBOARD | Gdk.SeatCapabilities.POINTER, true, null, null, null);
                        this.show_all();
                        GLib.Timeout.add_seconds(2, () => {
                            var window = (Gtk.Window) this.get_toplevel();
                            new HandleScreenMode(window, "WINDOW", curr_x, curr_y);
                            mode = "WINDOW";
                            if (current_key_sequence >= key_binding_info.get_length()) {
                                if (IS_SESSION_WAYLAND) linux_onboarding.seat.ungrab();
                                workflowList();
                                this.destroy();
                                return false;
                            }
                            obj = key_binding_info.get_element(current_key_sequence).get_object();
                            try {
                                reset_ui_for_next_step(obj, buttonHolder);
                            } catch (Error e) {
                                stderr.printf("Error advancing step: %s\n", e.message);
                            }
                            return false;
                        });
                    }
                    return false;
                });

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
                            try {
                                Process.spawn_command_line_sync(wm_cmd + " mode '" + WM_MODE_NAME + "'");
                            } catch (Error e) {
                                stderr.printf("Failed to re-enter WM mode: %s\n", e.message);
                            }
                        } else if (setup_wm_mode(key_binding_info)) {
                            use_wm_mode = true;

                            ipc_watch_id = ipc_channel.add_watch(
                                GLib.IOCondition.IN | GLib.IOCondition.HUP,
                                (src, cond) => {
                                    if ((cond & GLib.IOCondition.HUP) != 0)
                                        return false;
                                    try {
                                        string line;
                                        size_t length, term_pos;
                                        if (src.read_line(out line, out length, out term_pos) != GLib.IOStatus.NORMAL)
                                            return true;
                                        if (line == null) return true;
                                        line = line.strip();
                                        if (line.length == 0) return true;

                                        // Skip subscription acknowledgement: [{"success":true}]
                                        if (line.has_prefix("[")) return true;

                                        if (mode != "TILEUP") return true;

                                        var parser = new Json.Parser();
                                        parser.load_from_data(line);
                                        var root_obj = parser.get_root().get_object();
                                        if (root_obj.get_string_member("change") != "run") return true;

                                        var bnd = root_obj.get_object_member("binding");
                                        var sym_node = bnd.get_member("symbol");
                                        if (sym_node == null || sym_node.is_null()) return true;
                                        var symbol = sym_node.get_string();
                                        var mask_arr = bnd.get_array_member("event_state_mask");

                                        if (symbol == "Escape") {
                                            teardown_wm_mode();
                                            var win = (Gtk.Window) this.get_toplevel();
                                            new HandleScreenMode(win, "WINDOW", curr_x, curr_y);
                                            mode = "WINDOW";
                                            workflowList();
                                            this.destroy();
                                            return false;
                                        }

                                        var cfg = new configManager();
                                        var expected = cfg.format_spec_for_mode(command);
                                        if (expected == "") return true;

                                        if (!ipc_event_matches(expected, symbol, mask_arr)) return true;

                                        // Block re-matches while the tick-display timeout is pending.
                                        mode = "WINDOW";
                                        var wm_cmd_l = (WM_NAME == "sway") ? "swaymsg" : "i3-msg";
                                        current_key_sequence++;
                                        try { Process.spawn_command_line_sync(wm_cmd_l + " mode default"); } catch {}

                                        if (!execute_via_sway_binding(expected))
                                            Posix.system(execCommand);

                                        handleTick();
                                        this.show_all();

                                        GLib.Timeout.add_seconds(2, () => {
                                            var toplevel = this.get_toplevel();
                                            if (!(toplevel is Gtk.Window)) return false;
                                            var win = (Gtk.Window) toplevel;
                                            new HandleScreenMode(win, "WINDOW", curr_x, curr_y);

                                            if (current_key_sequence >= key_binding_info.get_length()) {
                                                teardown_wm_mode();
                                                workflowList();
                                                this.destroy();
                                                return false;
                                            }

                                            obj = key_binding_info.get_element(current_key_sequence).get_object();
                                            try {
                                                reset_ui_for_next_step(obj, buttonHolder);
                                                execCommandString();
                                            } catch (Error e) {
                                                stderr.printf("Error advancing step: %s\n", e.message);
                                            }
                                            return false;
                                        });

                                    } catch (Error e) {
                                        stderr.printf("IPC event error: %s\n", e.message);
                                    }
                                    return true;
                                });

                            // Deferred mode entry: lets sway finish post-reload cleanup before
                            // we send the mode command, avoiding a race that resets mode to "default".
                            GLib.Timeout.add(300, () => {
                                try {
                                    var wm_cmd_enter = (WM_NAME == "sway") ? "swaymsg" : "i3-msg";
                                    Process.spawn_command_line_sync(wm_cmd_enter + " mode '" + WM_MODE_NAME + "'");
                                } catch (Error e) {
                                    stderr.printf("Failed to enter WM mode: %s\n", e.message);
                                }
                                return false;
                            });

                        } else {
                            stderr.printf("setup_wm_mode() failed — falling back to seat.grab\n");
                            use_wm_mode = false;
                            if (IS_SESSION_WAYLAND) {
                                var gdkwin = this.get_window();
                                if (gdkwin != null) {
                                    var grabbed = grab_inputs(gdkwin);
                                    if (grabbed != null)
                                        linux_onboarding.seat = grabbed;
                                    else
                                        stderr.printf("Failed to grab input devices.\n");
                                }
                            }
                        }
                        this.show_all();
                    }
                });

                cancel_button.clicked.connect(() => {
                    if (use_wm_mode) {
                        teardown_wm_mode();
                    } else if (IS_SESSION_WAYLAND) {
                        linux_onboarding.seat.ungrab();
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

        // Resets all UI labels/images after a step completes and loads the next one.
        private void reset_ui_for_next_step(Json.Object next_obj, Gtk.Box buttonHolder) throws Error {
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

        // Writes a mode block to the user's sway/i3 config.d directory (auto-included by
        // the active Regolith config), reloads the WM, and subscribes to IPC binding events.
        // Returns true on success; caller falls back to seat.grab on false.
        private bool setup_wm_mode(Json.Array key_binding_info) {
            if (WM_NAME != "sway" && WM_NAME != "i3") return false;

            var wm_cmd = (WM_NAME == "sway") ? "swaymsg" : "i3-msg";
            var cfg = new configManager();

            var config_d = find_or_create_config_d();
            if (config_d == null) return false;
            mode_file_path = Path.build_filename(config_d, "linux_onboarding_mode");

            var sb = new StringBuilder();
            sb.append("mode \"" + WM_MODE_NAME + "\" {\n");
            for (int i = 0; i < (int)key_binding_info.get_length(); i++) {
                try {
                    var element = key_binding_info.get_element(i);
                    if (element == null || element.get_node_type() != Json.NodeType.OBJECT) continue;
                    var kobj = element.get_object();
                    if (!kobj.has_member("key_id")) continue;
                    var wm_key = cfg.format_spec_for_mode(kobj.get_string_member("key_id"));
                    if (wm_key == "") continue;
                    sb.append("    bindsym " + wm_key + " nop\n");
                } catch (Error e) {
                    stderr.printf("Error reading key binding: %s\n", e.message);
                }
            }
            sb.append("    bindsym Escape nop\n");
            sb.append("}\n");

            try {
                var f = File.new_for_path(mode_file_path);
                var w = new DataOutputStream(f.replace(null, false, FileCreateFlags.NONE));
                w.put_string(sb.str);
                w.close();
            } catch (Error e) {
                stderr.printf("Failed to write mode file: %s\n", e.message);
                return false;
            }

            try {
                Process.spawn_command_line_sync(wm_cmd + " reload");
            } catch (Error e) {
                stderr.printf("WM reload failed: %s\n", e.message);
                cleanup_mode_file();
                return false;
            }

            // Small delay so sway finishes processing the reload before we subscribe.
            GLib.Thread.usleep(200 * 1000);

            try {
                int stdout_fd;
                string[] argv = {wm_cmd, "-t", "subscribe", "-m", "[\"binding\"]"};
                Process.spawn_async_with_pipes(
                    null, argv, null,
                    SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                    null, out ipc_pid, null, out stdout_fd, null);
                ipc_channel = new GLib.IOChannel.unix_new(stdout_fd);
            } catch (Error e) {
                stderr.printf("IPC subscribe failed: %s\n", e.message);
                cleanup_mode_file();
                return false;
            }

            return true;
        }

        private void teardown_wm_mode() {
            var wm_cmd = (WM_NAME == "sway") ? "swaymsg" : "i3-msg";
            try { Process.spawn_command_line_sync(wm_cmd + " mode default"); } catch {}

            if (ipc_watch_id != 0) { GLib.Source.remove(ipc_watch_id); ipc_watch_id = 0; }
            if (ipc_channel != null) { try { ipc_channel.shutdown(false); } catch {} ipc_channel = null; }
            if (ipc_pid != 0) {
                Posix.kill((Posix.pid_t)ipc_pid, Posix.Signal.TERM);
                ChildWatch.add(ipc_pid, (pid, status) => { Process.close_pid(pid); });
                ipc_pid = 0;
            }

            cleanup_mode_file();
            use_wm_mode = false;
        }

        private void cleanup_mode_file() {
            if (mode_file_path == "") return;
            var wm_cmd = (WM_NAME == "sway") ? "swaymsg" : "i3-msg";
            try { File.new_for_path(mode_file_path).delete(); } catch {}
            mode_file_path = "";
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
                if (FileUtils.test(dir, FileTest.IS_DIR)) return dir;
            }
            try {
                File.new_for_path(candidates[0]).make_directory_with_parents();
                return candidates[0];
            } catch (Error e) {
                stderr.printf("Cannot find or create config.d: %s\n", e.message);
                return null;
            }
        }

        // Returns true when the sway IPC binding event matches the expected key spec (e.g. "Mod4+Return").
        private bool ipc_event_matches(string expected, string symbol, Json.Array mask_arr) {
            var parts = expected.split("+");
            if (symbol != parts[parts.length - 1]) return false;

            int expected_mod_count = parts.length - 1;
            if (expected_mod_count != (int)mask_arr.get_length()) return false;

            for (int i = 0; i < expected_mod_count; i++) {
                var actual_mod = mask_arr.get_element(i).get_string().down();
                bool found = false;
                for (int j = 0; j < expected_mod_count; j++) {
                    if (parts[j].down() == actual_mod) { found = true; break; }
                }
                if (!found) return false;
            }
            return true;
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

        // Finds the sway command for key_spec by scanning config files, then dispatches via swaymsg.
        // Reads main Regolith config files for variable definitions ($mod etc.) and config.d for bindsyms.
        // Returns true if a command was found and dispatched (or is nop).
        private bool execute_via_sway_binding(string key_spec) {
            if (WM_NAME != "sway" || key_spec.length == 0) return false;

            string home = Environment.get_home_dir();
            var var_list = new GLib.Array<string>();
            var all_content = new StringBuilder();

            // Read main config files — $mod and other variables are defined here, not in config.d
            string[] main_configs = {
                "/usr/share/regolith/sway/config",
                "/usr/share/regolith/common/sway/config",
                Path.build_filename(home, ".config", "regolith3", "sway", "config"),
                Path.build_filename(home, ".config", "sway", "config"),
            };
            foreach (var src in main_configs) {
                string contents = "";
                try { FileUtils.get_contents(src, out contents); } catch { continue; }
                foreach (var line in contents.split("\n"))
                    parse_var_line(line.strip(), var_list);
                all_content.append("\n");
                all_content.append(contents);
            }

            // Also try the last-loaded config from swaymsg
            string cfg_json = "";
            try { Process.spawn_command_line_sync("swaymsg -t get_config", out cfg_json, null, null); } catch {}
            if (cfg_json.length > 0) {
                string main_cfg = "";
                try {
                    var p = new Json.Parser();
                    p.load_from_data(cfg_json);
                    main_cfg = p.get_root().get_object().get_string_member("config");
                } catch { main_cfg = cfg_json; }
                foreach (var line in main_cfg.split("\n"))
                    parse_var_line(line.strip(), var_list);
                all_content.append("\n");
                all_content.append(main_cfg);
            }

            // Scan config.d directories for bindsym lines
            string[] search_dirs = {
                "/usr/share/regolith/common/config.d",
                "/usr/share/regolith/sway/config.d",
                "/etc/regolith3/sway/config.d",
                Path.build_filename(home, ".config", "regolith3", "common-wm", "config.d"),
                Path.build_filename(home, ".config", "regolith3", "sway", "config.d"),
                Path.build_filename(home, ".config", "regolith2", "sway", "config.d"),
                Path.build_filename(home, ".config", "sway", "config.d"),
            };
            foreach (var dir in search_dirs) {
                if (!FileUtils.test(dir, FileTest.IS_DIR)) continue;
                try {
                    var d = Dir.open(dir, 0);
                    string? fn;
                    while ((fn = d.read_name()) != null) {
                        string contents = "";
                        try {
                            FileUtils.get_contents(Path.build_filename(dir, fn), out contents);
                            all_content.append("\n");
                            all_content.append(contents);
                        } catch {}
                    }
                } catch {}
            }

            string[] lines = all_content.str.split("\n");
            // Second pass: pick up any vars defined inside config.d files
            foreach (var line in lines)
                parse_var_line(line.strip(), var_list);

            // Scan top-level bindsym lines (depth 0) for a match
            int depth = 0;
            foreach (var line in lines) {
                var s = line.strip();
                if (s.has_suffix("{")) { depth++; continue; }
                if (s == "}") { if (depth > 0) depth--; continue; }
                if (depth != 0 || !s.has_prefix("bindsym ")) continue;

                string resolved = s;
                for (uint i = 0; i + 1 < var_list.length; i += 2)
                    resolved = resolved.replace(var_list.index(i), var_list.index(i + 1));

                string rest = resolved.substring("bindsym ".length).strip();
                while (rest.has_prefix("--")) {
                    int sp = rest.index_of(" ");
                    if (sp < 0) { rest = ""; break; }
                    rest = rest.substring(sp).strip();
                }
                if (rest.length == 0) continue;
                int sp = rest.index_of(" ");
                if (sp < 0) continue;
                string bkey = rest.substring(0, sp).strip();
                string bcmd = rest.substring(sp).strip();

                if (!keys_match(bkey, key_spec)) continue;
                if (bcmd == "nop" || bcmd.length == 0) return true;

                try {
                    string[] argv = {"swaymsg", bcmd};
                    Process.spawn_sync(null, argv, null, SpawnFlags.SEARCH_PATH, null, null, null, null);
                    return true;
                } catch (Error e) {
                    stderr.printf("swaymsg dispatch: %s\n", e.message);
                    return false;
                }
            }

            return false;
        }

        // Extracts set/$mod and set_from_resource variable definitions from a config line.
        // Uses the default value for set_from_resource (xrdb is unreliable on Wayland).
        private void parse_var_line(string s, GLib.Array<string> out_list) {
            if (s.has_prefix("set ") && !s.has_prefix("set_from_resource ")) {
                var parts = s.split(" ", 3);
                if (parts.length >= 3 && parts[1].has_prefix("$")) {
                    out_list.append_val(parts[1]);
                    out_list.append_val(parts[2].strip());
                }
            } else if (s.has_prefix("set_from_resource ")) {
                // "set_from_resource $name resource_name default"
                var parts = s.split(" ");
                if (parts.length >= 4 && parts[1].has_prefix("$")) {
                    out_list.append_val(parts[1]);
                    out_list.append_val(parts[3].strip());
                }
            }
        }

        // Modifier order and case are ignored: "Mod4+Shift+Return" == "shift+mod4+Return"
        private bool keys_match(string a, string b) {
            return sort_key_spec(a.down()) == sort_key_spec(b.down());
        }

        private string sort_key_spec(string key_spec) {
            var parts = key_spec.split("+");
            if (parts.length <= 1) return key_spec;
            string symbol = parts[parts.length - 1];
            string[] mods = {};
            for (int i = 0; i < parts.length - 1; i++) mods += parts[i];
            for (int i = 1; i < mods.length; i++) {
                string key = mods[i];
                int j = i - 1;
                while (j >= 0 && mods[j] > key) { mods[j + 1] = mods[j]; j--; }
                mods[j + 1] = key;
            }
            return string.joinv("+", mods) + "+" + symbol;
        }

        // ydotool uses Linux input-event key names (KEY_ENTER) rather than X11 keysym names (Return).
        private string to_ydotool_key(string xkey) {
            switch (xkey) {
                case "Return":    return "KEY_ENTER";
                case "Up":        return "KEY_UP";
                case "Down":      return "KEY_DOWN";
                case "Left":      return "KEY_LEFT";
                case "Right":     return "KEY_RIGHT";
                case "Caps_Lock": return "KEY_CAPSLOCK";
                case "Shift_L":   return "KEY_LEFTSHIFT";
                case "Alt_L":     return "KEY_LEFTALT";
                case "Control_L": return "KEY_LEFTCTRL";
                case "Super_L":   return "KEY_LEFTMETA";
                default:          return xkey;
            }
        }

        public void execCommandString() {
            var configmanager = new configManager();
            bool use_ydotool = false;
            if (IS_SESSION_WAYLAND) {
                string? ydotool_path = GLib.Environment.find_program_in_path("ydotool");
                use_ydotool = (ydotool_path != null);
                execCommand = use_ydotool
                    ? "ydotool key "
                    : "xdotool sleep 0.5 key --clearmodifiers ";
            } else {
                execCommand = "xdotool sleep 0.5 key --clearmodifiers ";
            }

            string[] splitCommands = configmanager.format_spec(command).split(" ");
            for (int i = 0; i < splitCommands.length - 1; i++) {
                var k = keypressHandler.remontoireSymToKey[splitCommands[i]];
                execCommand += (use_ydotool ? to_ydotool_key(k) : k) + "+";
            }
            var last = splitCommands[splitCommands.length - 1];
            var raw = (keypressHandler.remontoireSymToKey.get(last) != (string)null)
                ? keypressHandler.remontoireSymToKey[last]
                : last;
            execCommand += use_ydotool ? to_ydotool_key(raw) : raw;
        }

        private Gdk.Seat? grab_inputs(Gdk.Window gdkwin) {
            var display = gdkwin.get_display();
            if (display == null) { stderr.printf("Failed to get Display\n"); return null; }
            var seat = display.get_default_seat();
            if (seat == null) { stderr.printf("Failed to get Seat\n"); return null; }

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
