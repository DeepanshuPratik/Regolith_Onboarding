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
     * version the user has already been shown, **on each desktop**.
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
     * An absent record means never-seen-anything rather than seen-nothing (D10).
     * There is no delta to compute with no history, so the answer is the whole
     * deck.
     *
     * ## Per desktop, not per machine (#31)
     *
     * This used to hold one record for the whole machine, which was wrong in a
     * way that only showed up when someone moved between desktops: logging into
     * GNOME after Regolith produced no slides at all, because the deck had been
     * marked seen by a session that was never GNOME. The slides are the same
     * either way — branding is compiled in — but what they introduce, the
     * workflow catalogue and the practice loop, is different on each desktop, so
     * being shown them once per desktop is the intent.
     *
     * The keying is the desktop id the caller passes in, which is
     * SessionProbe.primary_desktop() in the app: already normalised, with the
     * session-type suffix stripped, so `Regolith-Wayland` and `Regolith-X11`
     * share one record exactly as they share one workflow directory. Taking it
     * as an argument rather than reaching for PlatformRegistry is what keeps this
     * class free of the platform tree, and testable against a real file.
     *
     * One file with a group per desktop, rather than a file per desktop: it
     * keeps --reset-state a single unlink that can still name what it removed,
     * and it keeps the file readable by whoever opens it.
     */
    public class OnboardingState : GLib.Object {

        private const string FILENAME = "state";

        /**
         * The group a build before #31 wrote: one record, no desktop. See
         * load_from() for why it is not honoured.
         */
        private const string LEGACY_GROUP = "State";

        private const string GROUP_PREFIX = LEGACY_GROUP + ":";
        private const string KEY          = "LastSeenBrandingVersion";

        // Which file and whose record. Held so that record() writes back exactly
        // where load_from() read, which is what makes a temp file in a test the
        // same code path as the real one.
        private string file;
        private string desktop;

        /**
         * The branding version this user has been shown in full **on this
         * desktop**, or null when there is no history for it — see the class
         * comment for why those are different answers.
         */
        public string? last_seen_version { get; private set; default = null; }

        private OnboardingState (string file, string desktop) {
            this.file = file;
            this.desktop = desktop;
        }

        /** Where the file is. Public so --reset-state can name it in its output. */
        public static string path () {
            return Path.build_filename (Environment.get_user_config_dir (),
                                        DATA_SUBDIR, FILENAME);
        }

        /**
         * The group holding one desktop's record.
         *
         * Sanitised, because the id ultimately comes from XDG_CURRENT_DESKTOP and
         * a distro can put anything there. A KeyFile group name may not contain
         * `[` or `]`, and whitespace either side of a name is not preserved on
         * re-read — either would mean writing a record that cannot be found
         * again, which reads as "you have never seen the deck" every single run.
         * Anything outside a conservative set is dropped rather than escaped: the
         * ids in play are lowercase words, and a dropped character can at worst
         * merge two desktops nobody ships.
         */
        public static string group_for (string desktop) {
            var clean = new StringBuilder ();
            foreach (var c in desktop.down ().to_utf8 ()) {
                if (c.isalnum () || c == '.' || c == '_' || c == '-') clean.append_c (c);
            }
            return GROUP_PREFIX + (clean.len > 0 ? clean.str : Desktop.FALLBACK_ID);
        }

        /** This desktop's record, from the file the app keeps. */
        public static OnboardingState load (string desktop) {
            return load_from (path (), desktop);
        }

        /**
         * As load(), against a named file. internal so the suite can drive the
         * real parser over a real temp file instead of a stand-in.
         */
        internal static OnboardingState load_from (string file, string desktop) {
            var state = new OnboardingState (file, desktop);
            var keyfile = new KeyFile ();
            try {
                keyfile.load_from_file (file, KeyFileFlags.NONE);
            } catch (Error e) {
                // No file yet, or one hand-edited into something unreadable.
                // Either way there is no history, which is exactly the first-run
                // answer — nothing to report and nothing to repair.
                return state;
            }

            var group = group_for (desktop);
            if (!keyfile.has_group (group)) {
                // A legacy file records a version but not who saw it, so it
                // cannot be honoured for any particular desktop. Ignoring it
                // replays the deck once on the desktop that did see it; honouring
                // it would hide the deck on every desktop that did not. Showing a
                // slide twice is an annoyance, never showing it is the bug.
                if (keyfile.has_group (LEGACY_GROUP)) {
                    message ("state: the record in %s predates per-desktop state; " +
                             "treating '%s' as a first run", file, desktop);
                }
                return state;
            }

            try {
                var seen = keyfile.get_string (group, KEY).strip ();
                if (Version.is_valid (seen)) {
                    state.last_seen_version = seen;
                } else {
                    warning ("state: '%s' is not a dotted-numeric version; " +
                             "treating this as a first run", seen);
                }
            } catch (Error e) {
                // The group exists without the key in it. Same answer.
            }
            return state;
        }

        /**
         * Records `version` as seen on this desktop. Called once the deck has
         * actually been shown through, never at startup — see CarouselSetup for
         * why that distinction is the whole point of this class.
         *
         * Every other desktop's record is read back and rewritten untouched: a
         * write that dropped them would turn moving between two desktops into a
         * deck that replays forever on both.
         */
        public void record (string version) {
            if (!Version.is_valid (version)) return;
            if (last_seen_version == version) return;

            var keyfile = new KeyFile ();
            try {
                keyfile.load_from_file (file, KeyFileFlags.KEEP_COMMENTS);
            } catch (Error e) {
                // Nothing to preserve; this run writes the first record.
            }

            // Not merely unread but removed, so the next run does not report a
            // legacy file that is no longer legacy.
            if (keyfile.has_group (LEGACY_GROUP)) {
                try {
                    keyfile.remove_group (LEGACY_GROUP);
                } catch (Error e) {
                    warning ("state: cannot drop the pre-#31 group: %s", e.message);
                }
            }

            keyfile.set_string (group_for (desktop), KEY, version);
            try {
                DirUtils.create_with_parents (Path.get_dirname (file), 0755);
                FileUtils.set_contents (file, keyfile.to_data ());
                last_seen_version = version;
            } catch (Error e) {
                // Not fatal: the deck simply shows again next time, which is the
                // safe direction to fail in.
                warning ("cannot write %s: %s", file, e.message);
            }
        }

        /**
         * `linux-onboarding --reset-state`
         *
         * Forgets every desktop's recorded version so the next run is a first run
         * again. Worth a flag because without one a distro author cannot re-test
         * their own slides without knowing where this file lives and deleting it
         * by hand — and they are the people who change slides most often.
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
            stdout.printf ("Removed %s; the next run shows the full deck, on every desktop.\n", file);
            return 0;
        }
    }
}
