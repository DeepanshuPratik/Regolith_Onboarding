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
     * `linux-onboarding --check-workflows`
     *
     * Resolves every step of every discovered workflow without opening a window,
     * and reports what each key_id turns into: the bindsym the WM binding mode
     * would install, and the synthesized keypress used as a fallback.
     *
     * Worth having because a bad key_id fails quietly at runtime — the mode block
     * is rejected by the window manager, or the step simply never matches — and
     * that is exactly the kind of mistake someone authoring workflows for a new
     * distro will make.
     */
    public class WorkflowCheck : GLib.Object {

        public static int run () {
            var spec = new KeySpec ();
            var synth = new KeySynthesizer ();

            // The whole reason resolution is a service of its own: an author can
            // ask what their key_ids actually do on this desktop without opening
            // a window or pressing anything. BindingResolver's own contract names
            // this command as its offline consumer, and until now nothing here
            // called it.
            var resolver = PlatformRegistry.resolver ();

            stdout.printf ("%s\n", PlatformRegistry.probe ().describe ());
            stdout.printf ("branding: %s\n", Branding.get_default ().name);
            // What this desktop will actually be dressed in. Cheap to print and
            // the only way to check per-desktop theming without opening a window
            // on the desktop in question.
            stdout.printf ("palette:  accent %s, %s\n\n",
                           Palette.accent_hex (),
                           Palette.prefer_dark () ? "dark" : "light");

            var workflows = new WorkflowLocator ().load ();
            if (workflows.size == 0) {
                stdout.printf ("No workflows found for this desktop.\n");
                return 1;
            }

            int problems = 0;

            foreach (var workflow in workflows) {
                stdout.printf ("%s  (%s)\n", workflow.name, workflow.source);

                for (uint i = 0; i < workflow.steps.get_length (); i++) {
                    var element = workflow.steps.get_element (i);
                    if (element == null || element.get_node_type () != Json.NodeType.OBJECT) continue;
                    var step = element.get_object ();
                    if (!step.has_member ("key_id")) {
                        stdout.printf ("    !! step %u has no key_id\n", i);
                        problems++;
                        continue;
                    }

                    var key_id = step.get_string_member ("key_id");
                    var bindsym = spec.format_spec_for_mode (key_id);
                    var command = synth.command_for (key_id);

                    if (bindsym == "") {
                        stdout.printf ("    !! %-20s cannot be expressed as a bindsym; "
                                       + "this step can never be captured\n", key_id);
                        problems++;
                        continue;
                    }

                    if (bindsym.down ().has_suffix ("+escape") || bindsym.down () == "escape") {
                        stdout.printf ("    !! %-20s uses Escape, which is reserved for "
                                       + "leaving a workflow\n", key_id);
                        problems++;
                        continue;
                    }

                    stdout.printf ("    %-20s bindsym %-24s synth: %s\n",
                                   key_id, bindsym, command);
                    stdout.printf ("    %-20s %s\n", "", describe_binding (resolver, key_id));
                }
                stdout.printf ("\n");
            }

            if (!resolver.available ()) {
                stdout.printf ("Note: %s\n\n", resolver.unavailable_reason ());
            }

            if (problems > 0) {
                stdout.printf ("%d problem(s) found.\n", problems);
                return 1;
            }
            stdout.printf ("All steps resolve.\n");
            return 0;
        }

        /**
         * What this desktop says the key already does.
         *
         * None of the three answers is a problem, and none of them affects the
         * exit code. UNBOUND is an ordinary fact about a working desktop — most
         * GNOME defaults ship empty — and it tells the author their step will be
         * performed by synthesis rather than by the desktop's own action. UNKNOWN
         * means the desktop could not be consulted at all, which is the normal
         * answer on i3 and on any session with no resolver; reporting it as a
         * failure would make every such build look broken.
         */
        private static string describe_binding (BindingResolver resolver, string key_id) {
            string bound_to;
            switch (resolver.resolve (key_id, out bound_to)) {
                case BindingLookup.BOUND:
                    return "bound here to: " + bound_to;
                case BindingLookup.UNBOUND:
                    return "not bound on this desktop; the app will synthesize it";
                default:
                    return "binding unknown; the app will synthesize it";
            }
        }
    }
}
