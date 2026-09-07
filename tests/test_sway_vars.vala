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

namespace linux_onboarding.Tests {

    /**
     * Reading `set` and `set_from_resource` out of a sway config, and putting
     * those values back into a command.
     *
     * The bug these exist for, reported from a real run: practising the
     * keybinding-viewer step opened the *application launcher* instead, bigger
     * than usual. Regolith declares
     *
     *     set_from_resource $wm.program.help wm.program.help ilia -p keybindings
     *
     * and the parser took one token of that default, so `$wm.program.help`
     * became "ilia" and `-p keybindings` was dropped. What got dispatched was
     * `ilia -a` — ilia with all pages and no page selected, which is the
     * launcher with more in it. Precisely the symptom.
     */

    /** Config text in, one expanded command out — the resolver's own two steps. */
    private string vars_of (string config_text, string command) {
        var resolver = new SwayResolver ("sway");
        var vars = new GLib.Array<string> ();
        foreach (var line in config_text.split ("\n"))
            resolver.parse_var_line (line.strip (), vars);
        return resolver.resolve_vars (command, vars);
    }

    /** A default with spaces in it survives whole. */
    private void test_sway_var_multiword_default () {
        check_str ("program with arguments",
                   vars_of ("set_from_resource $wm.program.help wm.program.help ilia -p keybindings",
                            "exec $wm.program.help -a"),
                   "exec ilia -p keybindings -a");
    }

    /** The single-token case, which always worked, still does. */
    private void test_sway_var_single_word_default () {
        check_str ("mod",
                   vars_of ("set_from_resource $mod  wm.mod  Mod4", "bindsym $mod+Return nop"),
                   "bindsym Mod4+Return nop");
    }

    /**
     * A resource with no default in the file cannot be reproduced, so the token
     * is dropped rather than passed through as a literal "$name" — and the flag
     * that was waiting for it goes too, because a program handed `-t` with
     * nothing after it fails outright.
     */
    private void test_sway_var_no_default_drops_the_flag () {
        check_str ("dangling -t removed",
                   vars_of ("set_from_resource $ilia.stylesheet ilia.stylesheet",
                            "exec ilia -p keybindings -t $ilia.stylesheet"),
                   "exec ilia -p keybindings");
    }

    /** With the argument gone from the middle, what follows still runs. */
    private void test_sway_var_no_default_mid_command () {
        check_str ("middle of the line",
                   vars_of ("set_from_resource $sheet sheet", "exec ilia -t $sheet -a"),
                   "exec ilia -a");
    }

    /** A plain `set` keeps its multi-word value, as it always did. */
    private void test_sway_var_plain_set () {
        check_str ("set with spaces",
                   vars_of ("set $term /usr/bin/x-terminal-emulator --title work",
                            "exec $term"),
                   "exec /usr/bin/x-terminal-emulator --title work");
    }

    /** A variable nobody declared is left alone; we cannot invent it. */
    private void test_sway_var_unknown_is_untouched () {
        check_str ("unknown", vars_of ("set $other thing", "exec $mystery -a"),
                   "exec $mystery -a");
    }

    /**
     * The whole line from Regolith's config, which is what the report was
     * about. Two variables, one multi-word and one with no default at all.
     */
    private void test_sway_var_the_reported_line () {
        var cfg = "set_from_resource $wm.program.help wm.program.help ilia -p keybindings\n"
                + "set_from_resource $ilia.stylesheet ilia.stylesheet";
        check_str ("keybinding viewer",
                   vars_of (cfg, "exec --no-startup-id $wm.program.help -a -t $ilia.stylesheet"),
                   "exec --no-startup-id ilia -p keybindings -a");
    }

    public void register_sway_vars () {
        Test.add_func ("/sway-vars/multiword-default", test_sway_var_multiword_default);
        Test.add_func ("/sway-vars/single-word-default", test_sway_var_single_word_default);
        Test.add_func ("/sway-vars/no-default-drops-flag", test_sway_var_no_default_drops_the_flag);
        Test.add_func ("/sway-vars/no-default-mid-command", test_sway_var_no_default_mid_command);
        Test.add_func ("/sway-vars/plain-set", test_sway_var_plain_set);
        Test.add_func ("/sway-vars/unknown-untouched", test_sway_var_unknown_is_untouched);
        Test.add_func ("/sway-vars/reported-line", test_sway_var_the_reported_line);
    }
}
