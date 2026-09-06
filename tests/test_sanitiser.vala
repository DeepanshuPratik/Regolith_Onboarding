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
     * The bindsym-line sanitiser, which gates every line the app writes into
     * the user's sway `config.d`. A failure here is a supply-chain compromise:
     * a `key_id` containing a newline plus `}` terminates the mode block and
     * lets the WM execute whatever follows, in the user's config, on reload.
     *
     * Each case below is one the ticket calls out by name, plus a positive
     * case for the bundled Regolith spec. The point is not to enumerate every
     * possible attack — the character classes are small enough that the
     * source already does that — but to make sure none of those classes
     * silently falls through to a successful return.
     */
    public void register_sanitiser () {

        // The canonical attack: a key_id that, when concatenated into the
        // generated block, closes the mode and executes a command. The
        // sanitiser is what stops this from being a real config file.
        Test.add_func ("/sanitiser/blocks-mode-termination", () => {
            string key = "unset";
            string? reason = sanitise_key_id_for_mode ("Return nop\n} exec touch /tmp/pwned #", out key);
            check_bool ("rejected", reason != null, true);
            check_str  ("key unchanged", key, "");
        });

        Test.add_func ("/sanitiser/blocks-newline", () => {
            string key = "unset";
            string? reason = sanitise_key_id_for_mode ("a\nb", out key);
            check_bool ("rejected", reason != null, true);
        });

        // A literal '}' terminates the block even without a newline, and a
        // double-quote confuses the surrounding mode-name string on the next
        // reload. Both are single-character mistakes that should not slip
        // through.
        Test.add_func ("/sanitiser/blocks-closing-brace", () => {
            string key = "unset";
            string? reason = sanitise_key_id_for_mode ("a}b", out key);
            check_bool ("rejected", reason != null, true);
        });

        Test.add_func ("/sanitiser/blocks-double-quote", () => {
            string key = "unset";
            string? reason = sanitise_key_id_for_mode ("a\"b", out key);
            check_bool ("rejected", reason != null, true);
        });

        // '#' introduces a comment in sway config. A `key_id` that contains
        // one would let the rest of the line be silently discarded on reload,
        // which is not a useful attack but is a legitimate reason to reject.
        Test.add_func ("/sanitiser/blocks-comment-introducer", () => {
            string key = "unset";
            string? reason = sanitise_key_id_for_mode ("a #b", out key);
            check_bool ("rejected", reason != null, true);
        });

        // Empty after sanitising: a key_id that parses to "" rather than
        // blowing up on a structural character. The parser bug fixes handle
        // this path; the sanitiser still has to refuse to write nothing,
        // because `bindsym  nop` is a syntactically valid line that does
        // nothing useful and hides the failure.
        Test.add_func ("/sanitiser/blocks-empty-after-parse", () => {
            string key = "unset";
            string? reason = sanitise_key_id_for_mode ("<Shift", out key);
            check_bool ("rejected", reason != null, true);
        });

        // Empty input. Distinct from "parses to empty" because the check
        // is on the input shape, not on the parser's output.
        Test.add_func ("/sanitiser/blocks-empty-string", () => {
            string key = "unset";
            string? reason = sanitise_key_id_for_mode ("", out key);
            check_bool ("rejected", reason != null, true);
        });

        // Positive case: the bundled Regolith `<> Enter` spec must round-trip.
        Test.add_func ("/sanitiser/accepts-bundled-spec", () => {
            string key = "unset";
            string? reason = sanitise_key_id_for_mode ("<> Enter", out key);
            check_bool ("accepted", reason == null, true);
            check_str  ("bindsym", key, "Mod4+Return");
        });

        Test.add_func ("/sanitiser/accepts-modifier-stack", () => {
            string key = "unset";
            string? reason = sanitise_key_id_for_mode ("<><Shift> Enter", out key);
            check_bool ("accepted", reason == null, true);
            check_str  ("bindsym", key, "Mod4+Shift+Return");
        });
    }
}
