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
     * The command handed to ydotool.
     *
     * uinput KEY_* constants, which both ydotool generations accept — 0.1.8's
     * binary carries all 439 of them, 1.x documents them. This is pinned by
     * tests because the failure is invisible: handed a name it does not
     * recognise, 0.1.8 prints nothing and exits 0 (measured:
     * `ydotool key NOSUCHKEY123` succeeds), so a wrong vocabulary means the
     * step completes and the desktop does nothing.
     *
     * Note 0.1.8's own --help is misleading here. Its examples are alias forms
     * (`alt+r`, `Alt+F4`, `ctrl+Backspace`) and its alias table contains only
     * SUPER and SUPER_L; names like `slash` appear nowhere in the binary. So
     * following the help would produce commands that silently do nothing.
     */

    private void test_ydotool_command_for_shipped_steps () {
        var synth = new KeySynthesizer ();
        check_str ("terminal",
                   synth.ydotool_command_for ("<> Enter"),
                   "ydotool key KEY_LEFTMETA+KEY_ENTER");
        check_str ("browser",
                   synth.ydotool_command_for ("<><Shift> Enter"),
                   "ydotool key KEY_LEFTMETA+KEY_LEFTSHIFT+KEY_ENTER");
        check_str ("launcher",
                   synth.ydotool_command_for ("<> Space"),
                   "ydotool key KEY_LEFTMETA+KEY_SPACE");
    }

    /**
     * The keybinding-viewer step, which is where this came up. A shifted symbol
     * is sent as Shift plus the key physically beneath it — `?` is Shift and
     * the slash key — which is the same decomposition a hand-typed
     * `SUPER+Shift+/` performs.
     */
    private void test_ydotool_shifted_symbol () {
        var synth = new KeySynthesizer ();
        check_str ("question",
                   synth.ydotool_command_for ("<><Shift> ?"),
                   "ydotool key KEY_LEFTMETA+KEY_LEFTSHIFT+KEY_SLASH");
    }

    /** Arrows and letters, the rest of what the shipped workflows use. */
    private void test_ydotool_other_keys () {
        var synth = new KeySynthesizer ();
        check_str ("arrow",  synth.ydotool_command_for ("<> ←"), "ydotool key KEY_LEFTMETA+KEY_LEFT");
        check_str ("letter", synth.ydotool_command_for ("<> f"), "ydotool key KEY_LEFTMETA+KEY_F");
        check_str ("digit",  synth.ydotool_command_for ("<> 2"), "ydotool key KEY_LEFTMETA+KEY_2");
        check_str ("ctrl+alt",
                   synth.ydotool_command_for ("<Ctrl><Alt> t"),
                   "ydotool key KEY_LEFTCTRL+KEY_LEFTALT+KEY_T");
    }

    /** Every token is a KEY_ constant, so nothing needs shell quoting. */
    private void test_ydotool_command_is_shell_safe () {
        var synth = new KeySynthesizer ();
        var cmd = synth.ydotool_command_for ("<><Shift> ?");
        foreach (var c in ";|&`$<>()'\"".to_utf8 ()) {
            check_bool ("no shell metacharacter '%c'".printf (c), cmd.contains (c.to_string ()), false);
        }
    }

    public void register_ydotool_legacy () {
        Test.add_func ("/ydotool/shipped-steps", test_ydotool_command_for_shipped_steps);
        Test.add_func ("/ydotool/shifted-symbol", test_ydotool_shifted_symbol);
        Test.add_func ("/ydotool/other-keys", test_ydotool_other_keys);
        Test.add_func ("/ydotool/shell-safe", test_ydotool_command_is_shell_safe);
    }
}
