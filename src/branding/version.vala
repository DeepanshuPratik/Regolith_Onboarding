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
     * Ordering for the dotted-numeric versions that gate the slide deck:
     * `Version=` in branding.conf, and each slide's `Since=`.
     *
     * Numeric rather than lexical because the obvious shortcut is wrong in a way
     * nobody notices: compared as strings, "3.10" sorts *below* "3.9", so the
     * tenth branding revision would silently stop showing its own new slides.
     * No error, no log line, no crash — just an upgrade where the deck stays
     * empty. Segments are therefore parsed as numbers.
     *
     * There is deliberately no lenient path. A version that is not
     * dotted-numeric has no position in this order at all, so try_compare
     * refuses to answer rather than returning something plausible; the
     * alternative is "3.x" quietly ordering as 3.
     *
     * Pure and display-free, which is what makes the above testable.
     */
    public class Version : GLib.Object {

        /**
         * Whether text is one or more dot-separated runs of digits: "1", "1.0",
         * "3.10.2". Nothing else — no "v" prefix, no "1.0-rc1", no whitespace,
         * no empty segment.
         */
        public static bool is_valid (string text) {
            int digits_in_segment = 0;
            for (int i = 0; i < text.length; i++) {
                char c = text[i];
                if (c == '.') {
                    // Catches "", ".1" and "1..2"; the closing check catches "1.".
                    if (digits_in_segment == 0) return false;
                    digits_in_segment = 0;
                } else if (c >= '0' && c <= '9') {
                    digits_in_segment++;
                } else {
                    return false;
                }
            }
            return digits_in_segment > 0;
        }

        /**
         * Orders `a` against `b`, putting -1, 0 or +1 in `order`.
         *
         * Returns false when either side is malformed, and callers must not read
         * `order` then — a rejected version is not "equal" and not "lower", it is
         * unorderable, and reporting it as either is how a typo turns into a
         * slide that never shows.
         *
         * A missing segment counts as zero, so "3.2" and "3.2.0" are equal while
         * "3.2.1" is above both. Segment counts differ in practice as soon as a
         * distro adds a patch digit part-way through a series.
         */
        public static bool try_compare (string a, string b, out int order) {
            order = 0;
            if (!is_valid (a) || !is_valid (b)) return false;

            var left  = a.split (".");
            var right = b.split (".");
            var count = int.max (left.length, right.length);

            // Base 10 explicitly. int64.parse defaults to base 0, which reads a
            // leading zero as octal — so "1.09" would compare below "1.9"
            // instead of equal to it, and "1.08" would not parse at all. A
            // leading zero is a perfectly ordinary thing to write in a version.
            for (int i = 0; i < count; i++) {
                int64 l = (i < left.length)  ? int64.parse (left[i],  10) : 0;
                int64 r = (i < right.length) ? int64.parse (right[i], 10) : 0;
                if (l != r) {
                    order = (l < r) ? -1 : 1;
                    return true;
                }
            }
            return true;
        }

        /**
         * Whether `candidate` sits strictly above `baseline` — the question the
         * slide gate actually asks. A malformed side answers false, so a slide
         * with an unreadable Since is never counted as new.
         */
        public static bool is_above (string candidate, string baseline) {
            int order;
            if (!try_compare (candidate, baseline, out order)) return false;
            return order > 0;
        }
    }
}
