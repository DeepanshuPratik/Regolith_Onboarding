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
     * Performs a step's action on sway by running the command the key is really
     * bound to, falling back to replaying the keystroke when there is no such
     * command to run.
     *
     * Running the real command is preferred wherever it exists: synthesis has to
     * reproduce the exact modifier combination through a second keysym
     * translation, and a name ydotool does not recognise fails silently, which
     * looks exactly like the step doing nothing.
     */
    public class SwayDispatcher : GLib.Object, ActionDispatcher {

        private SwayResolver resolver;
        private KeySynthesizer synth = new KeySynthesizer ();
        private KeySpec spec = new KeySpec ();

        public SwayDispatcher (SwayResolver resolver) {
            this.resolver = resolver;
        }

        public bool available () { return true; }

        public string unavailable_reason () { return ""; }

        public bool dispatch (string key_id, string? bound_command) {
            // Nothing handed down: ask our own resolver, which is the only way to
            // tell "bound to nop on purpose" apart from "we found no binding".
            // Collapsing those two would make the app helpfully synthesize a key
            // the user's config went out of its way to disable.
            string command = bound_command;
            if (command == null) {
                string resolved;
                switch (resolver.resolve (key_id, out resolved)) {
                    case BindingLookup.BOUND:
                        command = resolved;
                        break;
                    case BindingLookup.UNBOUND:
                        debug_log ("'%s' is bound to nop; nothing to perform", key_id);
                        return true;
                    default:
                        var fallback = synth.command_for (key_id);
                        debug_log ("no WM binding for '%s'; synthesizing: %s",
                                   spec.format_spec_for_mode (key_id), fallback);
                        Posix.system (fallback);
                        return true;
                }
            }

            try {
                string[] argv = { "swaymsg", command };
                Process.spawn_sync (null, argv, null, SpawnFlags.SEARCH_PATH,
                                    null, null, null, null);
                debug_log ("dispatched '%s' via its real WM binding",
                           spec.format_spec_for_mode (key_id));
                return true;
            } catch (Error e) {
                stderr.printf ("swaymsg dispatch: %s\n", e.message);
                return false;
            }
        }

        [PrintfFormat]
        private void debug_log (string format, ...) {
            stdout.printf ("capture: %s\n", format.vprintf (va_list ()));
        }
    }
}
