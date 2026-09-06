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
     * The one thing this application remembers between runs: which branding
     * version the user has already been shown.
     *
     * It lives at $XDG_CONFIG_HOME/linux-onboarding/state, beside the workflows/
     * directory WorkflowLocator reads — same subdirectory constant, so a user
     * has one directory for this app and not two. It is a KeyFile because
     * branding.conf is, and one config syntax in a project is enough.
     *
     * What is stored is the *branding* version, not the application's (D11): a
     * bugfix release of the binary must not re-show a deck the user has already
     * read, and a branding-only change must be able to trigger one. The two
     * version numbers move for different reasons and belong to different people.
     *
     * An absent file means never-seen-anything rather than seen-nothing (D10).
     * There is no delta to compute on a machine with no history, so the answer
     * is the whole deck.
     */
    public class OnboardingState : GLib.Object {

        private const string FILENAME = "state";
        private const string GROUP    = "State";
        private const string KEY      = "LastSeenBrandingVersion";

        /**
         * The branding version this user has been shown in full, or null when
         * this machine has no history — see the class comment for why those are
         * different answers.
         */
        public string? last_seen_version { get; private set; default = null; }

        /** Where the file is. Public so --reset-state can name it in its output. */
        public static string path () {
            return Path.build_filename (Environment.get_user_config_dir (),
                                        WorkflowLocator.DATA_SUBDIR, FILENAME);
        }

        public static OnboardingState load () {
            var state = new OnboardingState ();
            var keyfile = new KeyFile ();
            try {
                keyfile.load_from_file (path (), KeyFileFlags.NONE);
                var seen = keyfile.get_string (GROUP, KEY).strip ();
                if (Version.is_valid (seen)) {
                    state.last_seen_version = seen;
                } else {
                    warning ("state: '%s' is not a dotted-numeric version; " +
                             "treating this as a first run", seen);
                }
            } catch (Error e) {
                // No file yet, or one hand-edited into something unreadable.
                // Either way there is no recorded history, which is exactly the
                // first-run answer — nothing to report and nothing to repair.
            }
            return state;
        }

        /**
         * Records `version` as seen. Called once the deck has actually been shown
         * through, never at startup — see CarouselSetup for why that distinction
         * is the whole point of this class.
         */
        public void record (string version) {
            if (!Version.is_valid (version)) return;
            if (last_seen_version == version) return;

            var keyfile = new KeyFile ();
            keyfile.set_string (GROUP, KEY, version);
            try {
                DirUtils.create_with_parents (Path.get_dirname (path ()), 0755);
                FileUtils.set_contents (path (), keyfile.to_data ());
                last_seen_version = version;
            } catch (Error e) {
                // Not fatal: the deck simply shows again next time, which is the
                // safe direction to fail in.
                warning ("cannot write %s: %s", path (), e.message);
            }
        }

        /**
         * `linux-onboarding --reset-state`
         *
         * Forgets the recorded version so the next run is a first run again.
         * Worth a flag because without one a distro author cannot re-test their
         * own slides without knowing where this file lives and deleting it by
         * hand — and they are the people who change slides most often.
         */
        public static int reset () {
            var file = path ();
            if (!FileUtils.test (file, FileTest.EXISTS)) {
                stdout.printf ("No state to reset: %s does not exist.\n", file);
                return 0;
            }
            if (FileUtils.unlink (file) != 0) {
                stderr.printf ("Cannot remove %s\n", file);
                return 1;
            }
            stdout.printf ("Removed %s; the next run shows the full deck.\n", file);
            return 0;
        }
    }
}
