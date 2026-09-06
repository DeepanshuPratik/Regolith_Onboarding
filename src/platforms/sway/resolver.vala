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

namespace linux_onboarding {

    /**
     * What a key is really bound to on sway, found by scanning the config the way
     * sway itself reads it: the main config files for `$variable` definitions,
     * then everything in config.d, resolving variables before comparing.
     *
     * This half used to be fused into dispatch — one method that scanned and ran
     * the first matching bindsym it found, so the answer was never visible and
     * could never be reused. Split out, --check-workflows can validate an
     * author's key_ids against the real desktop, and the dispatcher stops having
     * to re-derive what the scan already knew.
     *
     * sway only. i3 keeps no equivalent queryable config, so an i3 session gets
     * an unavailable resolver and everything falls through to synthesis.
     */
    public class SwayResolver : GLib.Object, BindingResolver {

        private bool is_sway;
        private KeySpec spec = new KeySpec ();

        public SwayResolver (string wm_id) {
            this.is_sway = wm_id == "sway";
        }

        public bool available () { return is_sway; }

        public string unavailable_reason () {
            return available () ? ""
                : "i3 exposes no queryable binding table; shortcuts will be synthesized instead.";
        }

        public BindingLookup resolve (string key_id, out string command) {
            command = "";
            if (!is_sway) return BindingLookup.UNKNOWN;

            var key_spec = spec.format_spec_for_mode (key_id);
            if (key_spec.length == 0) return BindingLookup.UNKNOWN;

            string home = Environment.get_home_dir ();
            var vars = new GLib.Array<string> ();
            var all = new StringBuilder ();

            // $mod and friends live in the main config, not in config.d.
            string[] main_configs = {
                "/etc/regolith/sway/config",
                "/usr/share/regolith/sway/config",
                "/usr/share/regolith/common/sway/config",
                Path.build_filename (home, ".config", "regolith3", "sway", "config"),
                Path.build_filename (home, ".config", "sway", "config"),
            };
            foreach (var src in main_configs) {
                string contents = "";
                try { FileUtils.get_contents (src, out contents); } catch { continue; }
                foreach (var line in contents.split ("\n"))
                    parse_var_line (line.strip (), vars);
                all.append ("\n");
                all.append (contents);
            }

            // Whatever sway actually last loaded, which may differ from the files.
            string cfg_json = "";
            try { Process.spawn_command_line_sync ("swaymsg -t get_config", out cfg_json, null, null); } catch {}
            if (cfg_json.length > 0) {
                string main_cfg = "";
                try {
                    var p = new Json.Parser ();
                    p.load_from_data (cfg_json);
                    main_cfg = p.get_root ().get_object ().get_string_member ("config");
                } catch { main_cfg = cfg_json; }
                foreach (var line in main_cfg.split ("\n"))
                    parse_var_line (line.strip (), vars);
                all.append ("\n");
                all.append (main_cfg);
            }

            string[] search_dirs = {
                "/usr/share/regolith/common/config.d",
                "/usr/share/regolith/sway/config.d",
                "/etc/regolith3/sway/config.d",
                Path.build_filename (home, ".config", "regolith3", "common-wm", "config.d"),
                Path.build_filename (home, ".config", "regolith3", "sway", "config.d"),
                Path.build_filename (home, ".config", "regolith2", "sway", "config.d"),
                Path.build_filename (home, ".config", "sway", "config.d"),
            };
            foreach (var dir in search_dirs) {
                if (!FileUtils.test (dir, FileTest.IS_DIR)) continue;
                try {
                    var d = Dir.open (dir, 0);
                    string? fn;
                    while ((fn = d.read_name ()) != null) {
                        string contents = "";
                        try {
                            FileUtils.get_contents (Path.build_filename (dir, fn), out contents);
                            all.append ("\n");
                            all.append (contents);
                        } catch {}
                    }
                } catch {}
            }

            string[] lines = all.str.split ("\n");
            // config.d fragments can define variables of their own.
            foreach (var line in lines)
                parse_var_line (line.strip (), vars);

            // Only top-level bindsyms; ones nested in a mode block are not active.
            int depth = 0;
            foreach (var line in lines) {
                var s = line.strip ();
                if (s.has_suffix ("{")) { depth++; continue; }
                if (s == "}") { if (depth > 0) depth--; continue; }
                if (depth != 0 || !s.has_prefix ("bindsym ")) continue;

                string resolved = resolve_vars (s, vars);

                string rest = resolved.substring ("bindsym ".length).strip ();
                while (rest.has_prefix ("--")) {          // --no-warn, --locked, ...
                    int flag_end = rest.index_of (" ");
                    if (flag_end < 0) { rest = ""; break; }
                    rest = rest.substring (flag_end).strip ();
                }
                if (rest.length == 0) continue;
                int sp = rest.index_of (" ");
                if (sp < 0) continue;

                string bound_key = rest.substring (0, sp).strip ();
                string bound_cmd = rest.substring (sp).strip ();

                if (!keys_match (bound_key, key_spec)) continue;

                // An explicit `nop` is the desktop saying this key does nothing on
                // purpose. That is a real answer about a working config, and the
                // dispatcher must not paper over it by synthesizing the keystroke.
                if (bound_cmd == "nop" || bound_cmd.length == 0) return BindingLookup.UNBOUND;

                command = bound_cmd;
                return BindingLookup.BOUND;
            }

            // Nothing matched. UNKNOWN rather than UNBOUND: a scan that misses
            // something is not a key bound to nothing, and the config we can read
            // is not guaranteed to be the whole of what sway loaded.
            return BindingLookup.UNKNOWN;
        }

        /**
         * Collects `set` and `set_from_resource` definitions.
         *
         * For set_from_resource we take the shipped default rather than querying
         * xrdb, which is not reliable on Wayland. Note these lines are column-aligned
         * in the Regolith configs ("set_from_resource $mod  wm.mod Mod4"), so the
         * fields must be split on runs of whitespace — splitting on a single space
         * yields an empty token and shifts the default value out of position.
         */
        private void parse_var_line (string raw, GLib.Array<string> into) {
            var s = raw.replace ("\t", " ");

            if (s.has_prefix ("set_from_resource ")) {
                // set_from_resource $name resource_key default_value
                var parts = tokenize (s);
                if (parts.length >= 4 && parts[1].has_prefix ("$")) {
                    into.append_val (parts[1]);
                    into.append_val (unquote (parts[3]));
                }
            } else if (s.has_prefix ("set ")) {
                // set $name value   — the value may itself contain spaces
                var parts = tokenize (s);
                if (parts.length >= 3 && parts[1].has_prefix ("$")) {
                    int after_name = s.index_of (parts[1]) + parts[1].length;
                    into.append_val (parts[1]);
                    into.append_val (unquote (s.substring (after_name).strip ()));
                }
            }
        }

        private static string[] tokenize (string s) {
            string[] parts = {};
            foreach (var t in s.split (" ")) {
                var trimmed = t.strip ();
                if (trimmed.length > 0) parts += trimmed;
            }
            return parts;
        }

        private static string unquote (string s) {
            if (s.length >= 2 && s.has_prefix ("\"") && s.has_suffix ("\""))
                return s.substring (1, s.length - 2);
            return s;
        }

        /**
         * Substitutes $variables into a config line, longest name first.
         *
         * Order matters: Regolith defines both $ws1 and $ws10, and replacing the
         * shorter name first would rewrite "$ws10" into the value of $ws1 followed
         * by a stray "0".
         */
        private string resolve_vars (string line, GLib.Array<string> vars) {
            int count = (int) vars.length / 2;
            if (count == 0) return line;

            int[] order = new int[count];
            for (int i = 0; i < count; i++) order[i] = i;
            for (int i = 1; i < count; i++) {
                int key = order[i];
                int j = i - 1;
                while (j >= 0 && vars.index (order[j] * 2).length < vars.index (key * 2).length) {
                    order[j + 1] = order[j];
                    j--;
                }
                order[j + 1] = key;
            }

            string result = line;
            foreach (var idx in order)
                result = result.replace (vars.index (idx * 2), vars.index (idx * 2 + 1));
            return result;
        }

        // Modifier order and case are irrelevant: "Mod4+Shift+Return" == "shift+mod4+Return"
        private bool keys_match (string a, string b) {
            return sort_key_spec (a.down ()) == sort_key_spec (b.down ());
        }

        private string sort_key_spec (string key_spec) {
            var parts = key_spec.split ("+");
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
            return string.joinv ("+", mods) + "+" + symbol;
        }
    }
}
