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
     * The whole harness: the assertion helpers every suite shares, and the one
     * list of suites that main () runs.
     *
     * Only pure functions are covered — string and table work that needs no
     * display, no compositor and no GTK main loop. Observers, placers and
     * dispatchers are deliberately absent: they cannot be exercised without a
     * live session, and a test that needs one is a test nobody runs.
     *
     * Adding a suite is three edits, none of which re-decide anything:
     *   1. tests/test_<area>.vala, holding a register_<area> () of Test.add_func calls
     *   2. that filename in `test_cases`, and the .vala it exercises in
     *      `code_under_test`, both in tests/meson.build
     *   3. one register_ call in main () below.
     */

    /**
     * Reports a string mismatch and marks the test failed, without aborting.
     *
     * Deliberately not GLib.assert_cmpstr: that aborts the process, so the first
     * wrong expectation would hide every case after it. One run should report all
     * the damage, not just the earliest.
     */
    public void check_str (string label, string? actual, string? expected) {
        if (actual == expected) return;
        Test.message ("%s\n    expected: %s\n    actual:   %s",
                      label,
                      expected == null ? "(null)" : "\"" + expected + "\"",
                      actual   == null ? "(null)" : "\"" + actual   + "\"");
        Test.fail ();
    }

    /** As check_str, for the integer-valued tables. */
    public void check_int (string label, int actual, int expected) {
        if (actual == expected) return;
        Test.message ("%s\n    expected: %d\n    actual:   %d", label, expected, actual);
        Test.fail ();
    }

    /** As check_str, for predicates such as validity and ordering. */
    public void check_bool (string label, bool actual, bool expected) {
        if (actual == expected) return;
        Test.message ("%s\n    expected: %s\n    actual:   %s",
                      label, expected.to_string (), actual.to_string ());
        Test.fail ();
    }
}

public static int main (string[] args) {
    // KeySynthesizer.command_for asks Desktop whether the session is Wayland, and
    // Desktop reads that from the environment. Pinning it here keeps the
    // synthesized command identical whether the suite runs under sway, under X11
    // or in CI — the alternative is a test that passes on the author's machine
    // only. Set here rather than through meson's test(env:) so that running the
    // binary by hand behaves the same way.
    Environment.set_variable ("XDG_SESSION_TYPE", "x11", true);
    Environment.unset_variable ("GDK_BACKEND");

    Test.init (ref args);

    // Without this GLib aborts the process on the first failure ("Bail out!"),
    // so one wrong expectation hides every case after it. A run should report
    // all the damage, which is also what makes check_str's diagnostics useful.
    Test.set_nonfatal_assertions ();

    linux_onboarding.Tests.register_asset_fit ();
    linux_onboarding.Tests.register_desktop ();
    linux_onboarding.Tests.register_key_spec ();
    linux_onboarding.Tests.register_locator ();
    linux_onboarding.Tests.register_kde_bindings ();
    linux_onboarding.Tests.register_key_tables ();
    linux_onboarding.Tests.register_key_synthesizer ();
    linux_onboarding.Tests.register_palette ();
    linux_onboarding.Tests.register_sanitiser ();
    linux_onboarding.Tests.register_state ();
    linux_onboarding.Tests.register_sway_vars ();
    linux_onboarding.Tests.register_ydotool_legacy ();
    linux_onboarding.Tests.register_version ();

    return Test.run ();
}
