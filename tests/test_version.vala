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
     * Version orders branding.conf's `Version=` against a slide's `Since=`, and
     * that ordering decides whether an upgraded user is shown a slide at all.
     *
     * Every case here fails silently in production if it regresses. A slide that
     * should appear simply does not; there is no error to read, nothing in the
     * log, and the distro author testing on their own machine — which already
     * has the newest state recorded — is the least likely person to notice.
     */
    public void register_version () {

        // ---- ordering -------------------------------------------------------

        // The whole reason this is not a string comparison. "3.10" < "3.9"
        // lexically, so a build gating on strings stops showing new slides at
        // the tenth revision and keeps working for the nine before it, which is
        // exactly how the bug survives review.
        Test.add_func ("/version/compare/tenth-revision-beats-ninth", () => {
            check_bool ("3.10 above 3.9",  Version.is_above ("3.10", "3.9"),  true);
            check_bool ("3.9 above 3.10",  Version.is_above ("3.9",  "3.10"), false);
            check_bool ("1.20 above 1.3",  Version.is_above ("1.20", "1.3"),  true);
            check_bool ("2.0 above 10.0",  Version.is_above ("2.0",  "10.0"), false);
        });

        // Segment counts diverge as soon as a distro adds a patch digit part-way
        // through a series, so "3.2" and "3.2.1" get compared against each other
        // in real branding directories.
        Test.add_func ("/version/compare/unequal-segment-counts", () => {
            int order;

            check_bool ("3.2 vs 3.2.1 orderable",
                        Version.try_compare ("3.2", "3.2.1", out order), true);
            check_int ("3.2 vs 3.2.1", order, -1);

            check_bool ("3.2.1 vs 3.2 orderable",
                        Version.try_compare ("3.2.1", "3.2", out order), true);
            check_int ("3.2.1 vs 3.2", order, 1);

            // A missing segment is zero, not "unspecified", so these are equal
            // and a slide marked Since=3.2.0 must not reappear at Version=3.2.
            check_bool ("3.2 vs 3.2.0 orderable",
                        Version.try_compare ("3.2", "3.2.0", out order), true);
            check_int ("3.2 vs 3.2.0", order, 0);

            check_bool ("3.2.0 above 3.2", Version.is_above ("3.2.0", "3.2"), false);
        });

        Test.add_func ("/version/compare/single-segment-and-equality", () => {
            int order;

            check_bool ("1 vs 2 orderable", Version.try_compare ("1", "2", out order), true);
            check_int ("1 vs 2", order, -1);

            check_bool ("1.0 vs 1.0 orderable",
                        Version.try_compare ("1.0", "1.0", out order), true);
            check_int ("1.0 vs 1.0", order, 0);

            // "0" is what an undeclared Version and an undeclared Since both
            // fall back to, so nothing may sit above it by default.
            check_bool ("0 above 0", Version.is_above ("0", "0"), false);
        });

        // Leading zeroes are legal digits and must not change the value. This
        // case caught the default base of int64.parse being 0, not 10: "09" was
        // being read as octal, failing on the 9 and coming back as zero, so
        // "1.09" sorted below "1.9" while reading as the same number.
        Test.add_func ("/version/compare/leading-zeroes-are-numeric", () => {
            int order;
            check_bool ("1.09 vs 1.9 orderable",
                        Version.try_compare ("1.09", "1.9", out order), true);
            check_int ("1.09 vs 1.9", order, 0);
        });

        // ---- rejection ------------------------------------------------------

        Test.add_func ("/version/valid/accepts-dotted-numeric", () => {
            check_bool ("0",      Version.is_valid ("0"),      true);
            check_bool ("1.0",    Version.is_valid ("1.0"),    true);
            check_bool ("3.10.2", Version.is_valid ("3.10.2"), true);
        });

        // Everything an author actually types by mistake. A version tool that
        // accepts these has to invent a position for them, and any position it
        // invents is a slide shown or hidden for a reason nobody wrote down.
        Test.add_func ("/version/valid/rejects-everything-else", () => {
            check_bool ("empty",   Version.is_valid (""),        false);
            check_bool ("v1.0",    Version.is_valid ("v1.0"),    false);
            check_bool ("1.0-rc1", Version.is_valid ("1.0-rc1"), false);
            check_bool ("3.x",     Version.is_valid ("3.x"),     false);
            check_bool ("1.",      Version.is_valid ("1."),      false);
            check_bool (".1",      Version.is_valid (".1"),      false);
            check_bool ("1..2",    Version.is_valid ("1..2"),    false);
            check_bool ("1 .0",    Version.is_valid ("1 .0"),    false);
            check_bool ("1.0 ",    Version.is_valid ("1.0 "),    false);
        });

        // The point of the whole exercise: a malformed version is refused, not
        // parsed as far as it goes. "3.x" must not quietly become 3 and sort
        // above 2.9 — the author gets told, rather than getting a deck that
        // looks plausible and is wrong.
        Test.add_func ("/version/compare/malformed-is-refused-not-ordered", () => {
            int order;

            check_bool ("3.x vs 2.9 refused",
                        Version.try_compare ("3.x", "2.9", out order), false);
            check_bool ("2.9 vs 3.x refused",
                        Version.try_compare ("2.9", "3.x", out order), false);
            check_bool ("both malformed refused",
                        Version.try_compare ("beta", "beta", out order), false);

            // And the gate says "not new" for it, rather than "new" or crashing:
            // an unreadable Since keeps its slide out of every delta.
            check_bool ("3.x above 2.9",   Version.is_above ("3.x", "2.9"), false);
            check_bool ("v2.0 above 1.0",  Version.is_above ("v2.0", "1.0"), false);
        });
    }
}
