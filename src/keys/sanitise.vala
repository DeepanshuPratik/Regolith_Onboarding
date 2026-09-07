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
     * Verifies that a workflow `key_id` is safe to render as one line of a
     * sway `bindsym` config block, and returns the bindsym spec on success.
     *
     * Lives outside src/platforms/sway/ on purpose: this is the part of the
     * platform the rest of the build needs to be able to test without a
     * display, a running sway, or any of the rest of SwayModes. The
     * security-critical path — every line written to the user's `config.d`
     * comes through here — should be exercised by the harness rather than
     * waiting for a CI to boot a real WM.
     *
     * Returns: null on success; on rejection, a short reason suitable for
     * stderr and for --check-workflows to print. The returned reason must
     * name the offending character class, not the value, so an attacker
     * cannot read it as a confirmation of what their payload managed.
     */
    public static string? sanitise_key_id_for_mode (string key_id, out string key) {
        key = "";

        if (key_id.length == 0)
            return "empty key_id";

        // The structural controls of a sway config file. None of these may
        // ever appear in a `bindsym` line we generate, regardless of what
        // KeySpec's parser happens to return. The checks are character-class
        // rather than full structural parsing because the input is a single
        // workflow key and a single structural character is enough.
        if (key_id.contains ("\n") || key_id.contains ("\r"))
            return "key_id contains a newline";
        if (key_id.contains ("}"))
            return "key_id contains '}'";
        if (key_id.contains ("\""))
            return "key_id contains a '\"'";
        if (key_id.contains ("#"))
            return "key_id contains a '#' comment introducer";

        var spec = new KeySpec ();
        string parsed = spec.format_spec_for_mode (key_id);
        if (parsed.length == 0)
            return "key_id is not parseable as a key spec";

        key = parsed;
        return null;
    }
}
