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
     * OnboardingState, keyed per desktop.
     *
     * The bug these exist for: the state used to be one record per machine, so a
     * user who moved from Regolith to GNOME was told they had already seen a deck
     * that had never been shown on that desktop, and got no slides at all.
     *
     * These touch the filesystem, which the rest of the suite does not. That is
     * deliberate and cheap: the whole class is a KeyFile on disk, and a test that
     * mocked the file away would only be testing the mock. Each case gets its own
     * temporary directory and takes it with it.
     */

    private string state_tmpdir () {
        try {
            return DirUtils.make_tmp ("onboarding-state-XXXXXX");
        } catch (Error e) {
            Test.message ("cannot make a temp dir: %s", e.message);
            Test.fail ();
            return "/tmp";
        }
    }

    private string state_file_in (string dir) {
        return Path.build_filename (dir, "state");
    }

    private void remove_tree (string dir) {
        FileUtils.unlink (state_file_in (dir));
        DirUtils.remove (dir);
    }

    private void write_raw (string file, string contents) {
        try {
            FileUtils.set_contents (file, contents);
        } catch (Error e) {
            Test.message ("cannot write %s: %s", file, e.message);
            Test.fail ();
        }
    }

    /** A file that was never written is a first run, not a seen-nothing. */
    private void test_state_absent_file_is_first_run () {
        var dir = state_tmpdir ();
        var state = OnboardingState.load_from (state_file_in (dir), "regolith");
        check_str ("absent file", state.last_seen_version, null);
        remove_tree (dir);
    }

    /** The ordinary round trip: what was recorded comes back. */
    private void test_state_round_trip () {
        var dir = state_tmpdir ();
        var file = state_file_in (dir);

        OnboardingState.load_from (file, "regolith").record ("1.2");
        var reloaded = OnboardingState.load_from (file, "regolith");

        check_str ("same desktop reads its own record", reloaded.last_seen_version, "1.2");
        remove_tree (dir);
    }

    /**
     * The reported bug, as a test: seen on Regolith must not mean seen on GNOME.
     */
    private void test_state_is_not_shared_between_desktops () {
        var dir = state_tmpdir ();
        var file = state_file_in (dir);

        OnboardingState.load_from (file, "regolith").record ("1.2");
        var on_gnome = OnboardingState.load_from (file, "gnome");

        check_str ("switching desktop is a first run there",
                   on_gnome.last_seen_version, null);
        remove_tree (dir);
    }

    /** Two desktops in one file, each remembering its own version. */
    private void test_state_keeps_desktops_independent () {
        var dir = state_tmpdir ();
        var file = state_file_in (dir);

        OnboardingState.load_from (file, "regolith").record ("1.2");
        OnboardingState.load_from (file, "gnome").record ("1.5");

        check_str ("regolith kept its version",
                   OnboardingState.load_from (file, "regolith").last_seen_version, "1.2");
        check_str ("gnome kept its own",
                   OnboardingState.load_from (file, "gnome").last_seen_version, "1.5");
        remove_tree (dir);
    }

    /** Recording again on the same desktop moves it forward, not sideways. */
    private void test_state_record_overwrites_same_desktop () {
        var dir = state_tmpdir ();
        var file = state_file_in (dir);

        OnboardingState.load_from (file, "gnome").record ("1.2");
        OnboardingState.load_from (file, "gnome").record ("1.3");

        check_str ("later record wins",
                   OnboardingState.load_from (file, "gnome").last_seen_version, "1.3");
        remove_tree (dir);
    }

    /**
     * A version that is not dotted-numeric is refused rather than stored, or the
     * comparison that gates the deck would be reading garbage next run.
     */
    private void test_state_rejects_a_bad_version () {
        var dir = state_tmpdir ();
        var file = state_file_in (dir);

        OnboardingState.load_from (file, "gnome").record ("2.0-beta");

        check_str ("bad version not stored",
                   OnboardingState.load_from (file, "gnome").last_seen_version, null);
        remove_tree (dir);
    }

    /** A hand-edited value is treated as no history, never as a version. */
    private void test_state_ignores_a_hand_edited_value () {
        var dir = state_tmpdir ();
        var file = state_file_in (dir);
        write_raw (file, "[State:gnome]\nLastSeenBrandingVersion=one point two\n");

        // The parser is expected to complain about this, and GLib's test
        // framework makes a warning fatal unless the case says it wants one.
        Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*not a dotted-numeric*");
        check_str ("unparseable value reads as first run",
                   OnboardingState.load_from (file, "gnome").last_seen_version, null);
        Test.assert_expected_messages ();
        remove_tree (dir);
    }

    /**
     * A file written by a build that had one global group records a version but
     * not who saw it, so it cannot be honoured for any particular desktop. It
     * reads as no history — the direction that shows slides again rather than
     * the one that hides them for good.
     */
    private void test_state_legacy_group_is_not_honoured () {
        var dir = state_tmpdir ();
        var file = state_file_in (dir);
        write_raw (file, "[State]\nLastSeenBrandingVersion=1.2\n");

        check_str ("legacy global group is not read as this desktop's",
                   OnboardingState.load_from (file, "gnome").last_seen_version, null);
        remove_tree (dir);
    }

    /** And it does not linger once this build has written the file. */
    private void test_state_legacy_group_is_cleared_on_record () {
        var dir = state_tmpdir ();
        var file = state_file_in (dir);
        write_raw (file, "[State]\nLastSeenBrandingVersion=1.2\n");

        OnboardingState.load_from (file, "gnome").record ("1.3");

        var keyfile = new KeyFile ();
        try {
            keyfile.load_from_file (file, KeyFileFlags.NONE);
        } catch (Error e) {
            Test.message ("cannot re-read %s: %s", file, e.message);
            Test.fail ();
            remove_tree (dir);
            return;
        }
        check_bool ("legacy group removed", keyfile.has_group ("State"), false);
        check_bool ("desktop group written", keyfile.has_group ("State:gnome"), true);
        remove_tree (dir);
    }

    /**
     * The group name is the whole of the keying, so it is pinned: a change here
     * silently re-shows the deck for every existing user.
     */
    private void test_state_group_naming () {
        check_str ("gnome",   OnboardingState.group_for ("gnome"),   "State:gnome");
        check_str ("default", OnboardingState.group_for ("default"), "State:default");
    }

    /**
     * Desktop ids come from XDG_CURRENT_DESKTOP, so they can carry whatever a
     * distro puts there. A group name has to survive that without splitting one
     * desktop into two records or colliding two into one.
     */
    private void test_state_group_naming_is_sanitised () {
        check_str ("bracket dropped",  OnboardingState.group_for ("gno[me]"), "State:gnome");
        check_str ("space dropped",    OnboardingState.group_for ("my desktop"), "State:mydesktop");
        check_str ("empty falls back", OnboardingState.group_for (""), "State:default");
    }

    public void register_state () {
        Test.add_func ("/state/absent-file-is-first-run", test_state_absent_file_is_first_run);
        Test.add_func ("/state/round-trip", test_state_round_trip);
        Test.add_func ("/state/not-shared-between-desktops", test_state_is_not_shared_between_desktops);
        Test.add_func ("/state/desktops-independent", test_state_keeps_desktops_independent);
        Test.add_func ("/state/record-overwrites", test_state_record_overwrites_same_desktop);
        Test.add_func ("/state/rejects-bad-version", test_state_rejects_a_bad_version);
        Test.add_func ("/state/ignores-hand-edited-value", test_state_ignores_a_hand_edited_value);
        Test.add_func ("/state/legacy-group-not-honoured", test_state_legacy_group_is_not_honoured);
        Test.add_func ("/state/legacy-group-cleared", test_state_legacy_group_is_cleared_on_record);
        Test.add_func ("/state/group-naming", test_state_group_naming);
        Test.add_func ("/state/group-naming-sanitised", test_state_group_naming_is_sanitised);
    }
}
