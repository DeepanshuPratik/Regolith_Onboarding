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
     * Desktop.build_candidates: turning a raw XDG_CURRENT_DESKTOP string into
     * the priority-ordered list workflow lookup walks.
     *
     * Driven directly against the raw string rather than through the Desktop
     * singleton, which reads the real environment once at first use — a test
     * that went through it would need to fork a process per case to see a
     * different XDG_CURRENT_DESKTOP, for no more coverage than calling the
     * pure function it delegates to.
     */

    /** Regolith's actual value: a session-type suffix, then its parent desktop, then its WM. */
    private void test_candidates_regolith_wayland_stack () {
        var candidates = Desktop.build_candidates ("Regolith-Wayland:GNOME:sway");
        check_int ("four entries", candidates.length, 4);
        check_str ("most specific", candidates[0], "regolith");
        check_str ("parent desktop", candidates[1], "gnome");
        check_str ("window manager", candidates[2], "sway");
        check_str ("always ends in fallback", candidates[3], Desktop.FALLBACK_ID);
    }

    /** The case reported from a plain Ubuntu GNOME session, with no Regolith anywhere. */
    private void test_candidates_ubuntu_gnome () {
        var candidates = Desktop.build_candidates ("Ubuntu:GNOME");
        check_int ("three entries", candidates.length, 3);
        check_str ("distro comes first", candidates[0], "ubuntu");
        check_str ("desktop second", candidates[1], "gnome");
        check_str ("always ends in fallback", candidates[2], Desktop.FALLBACK_ID);
    }

    /** -X11 and -Wayland are a session-type suffix, not part of the identity. */
    private void test_candidates_strips_session_type_suffix () {
        var wayland = Desktop.build_candidates ("Regolith-Wayland");
        var x11     = Desktop.build_candidates ("Regolith-X11");
        check_str ("wayland suffix stripped", wayland[0], "regolith");
        check_str ("x11 suffix stripped", x11[0], "regolith");
    }

    /** An unset XDG_CURRENT_DESKTOP is a first run on an unrecognised desktop, not an error. */
    private void test_candidates_empty_raw_is_just_default () {
        var candidates = Desktop.build_candidates ("");
        check_int ("only the fallback", candidates.length, 1);
        check_str ("fallback", candidates[0], Desktop.FALLBACK_ID);
    }

    /** A distro that repeats itself in the list still yields one candidate for it. */
    private void test_candidates_deduplicates () {
        var candidates = Desktop.build_candidates ("GNOME:gnome-classic:GNOME");
        check_int ("no duplicate gnome entries", candidates.length, 3);
        check_str ("first", candidates[0], "gnome");
        check_str ("second", candidates[1], "gnome-classic");
        check_str ("fallback", candidates[2], Desktop.FALLBACK_ID);
    }

    public void register_desktop () {
        Test.add_func ("/desktop/candidates-regolith-wayland-stack", test_candidates_regolith_wayland_stack);
        Test.add_func ("/desktop/candidates-ubuntu-gnome", test_candidates_ubuntu_gnome);
        Test.add_func ("/desktop/candidates-strips-session-type-suffix", test_candidates_strips_session_type_suffix);
        Test.add_func ("/desktop/candidates-empty-raw-is-just-default", test_candidates_empty_raw_is_just_default);
        Test.add_func ("/desktop/candidates-deduplicates", test_candidates_deduplicates);
    }
}
