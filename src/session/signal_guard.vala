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
     * What has to be undone if this process dies without running its own
     * shutdown, collected in advance so a signal handler can use it.
     *
     * A platform fills one of these at startup — see
     * Platform.collect_emergency_reset(). Two kinds of entry, because a crash
     * leaves two kinds of mess:
     *
     *  - **files**, which is config the app wrote into the user's window manager
     *    and which would otherwise sit there after the process is gone;
     *  - **one reset command**, because removing the file is not enough. Sway
     *    keeps the config it has already loaded, so a process that dies while
     *    the binding mode is *active* leaves the compositor inside a mode where
     *    every key the app named is bound to `nop`. Measured, not assumed: kill
     *    -SEGV mid-practice and `swaymsg -t get_binding_state` still answers
     *    "Onboarding" afterwards. The keyboard has to be handed back explicitly.
     */
    public class EmergencyReset : GLib.Object {

        internal string[] files;
        internal string[] command;

        public EmergencyReset () {
            files = {};
            command = {};
        }

        /** A file to unlink if the process dies abruptly. */
        public void add_file (string path) {
            files += path;
        }

        /**
         * The command that hands control back, as an absolute program path
         * followed by its arguments. Resolved to an absolute path by the caller,
         * because looking a program up on PATH is not something a signal handler
         * may do.
         *
         * Last writer wins; there is one keyboard to hand back.
         */
        public void set_command (string[] argv) {
            command = argv;
        }
    }

    /**
     * Cleans up when the process is killed or crashes.
     *
     * The app's ordinary exits — Escape, the window-manager close button,
     * Application.shutdown — all run release_practice() and take the binding
     * mode back out. Everything else skips that: GTK never reaches its shutdown
     * hook, no destroy handler fires, and what the app wrote into the user's
     * config stays there. Two families of "everything else", handled
     * differently on purpose:
     *
     *  - **Termination** (TERM, INT, HUP, QUIT) arrives at a healthy process, so
     *    the handler runs the full, ordinary cleanup through the registry: the
     *    same code the shutdown path uses, with its logging and its legacy
     *    filenames.
     *
     *  - **A crash** (SEGV, ABRT, BUS, FPE, ILL) arrives at a process whose
     *    state cannot be trusted. Allocating, taking a lock, or calling into
     *    GLib from that handler risks hanging or crashing again, and a hang here
     *    is worse than the crash: it leaves the keyboard captured with no
     *    process to kill. So the crash path uses only what POSIX says is safe
     *    to call from a signal handler — unlink(), fork(), execv(), _exit() —
     *    over data collected before any handler was installed.
     *
     * Either way the signal is re-raised with the default disposition, so a
     * crash still produces the exit status and the core dump it would have.
     * Swallowing a crash to look tidy would hide the bug that caused it.
     *
     * Two more hooks cover the exits that are neither, and they are the common
     * ones: the session ending underneath the app.
     *
     *  - **atexit**, for an orderly exit() that skips GTK's shutdown.
     *  - **a log writer**, because the case that actually happens skips atexit
     *    as well. When the connection to the compositor drops, GTK3 logs
     *    "Error reading events from display" and calls _exit(1) — no atexit, no
     *    signal. Logging is the last thing it does that we can see.
     *
     * Verified per signal in a nested compositor rather than reasoned about:
     * with the app inside the binding mode, each of SEGV, ABRT, BUS, FPE, ILL,
     * TERM, INT, HUP and QUIT leaves `swaymsg -t get_binding_state` reading
     * "default" and no mode file on disk, and a SIGSEGV still exits 139. Before
     * this, SEGV left the compositor in the mode with every practised key bound
     * to nop.
     */
    public class SignalGuard : GLib.Object {

        // Frozen before the handlers are installed. Static because a handler
        // has no receiver, and read-only afterwards so there is nothing to race.
        private static string[] files;
        private static string[] reset_command;

        // A crash inside the crash handler must not recurse.
        private static bool in_handler = false;

        private static bool armed = false;

        /**
         * Install the handlers, over state gathered from every platform that
         * claims this session.
         *
         * Called once, after the registry has resolved the session and before
         * anything is written to the user's config.
         */
        public static void arm () {
            if (armed) return;
            armed = true;

            var reset = new EmergencyReset ();
            PlatformRegistry.collect_emergency_reset (reset);
            files = reset.files;
            reset_command = reset.command;

            Posix.signal (Posix.Signal.TERM, on_termination);
            Posix.signal (Posix.Signal.INT,  on_termination);
            Posix.signal (Posix.Signal.HUP,  on_termination);
            Posix.signal (Posix.Signal.QUIT, on_termination);

            Posix.signal (Posix.Signal.SEGV, on_crash);
            Posix.signal (Posix.Signal.ABRT, on_crash);
            Posix.signal (Posix.Signal.BUS,  on_crash);
            Posix.signal (Posix.Signal.FPE,  on_crash);
            Posix.signal (Posix.Signal.ILL,  on_crash);

            // Covers an orderly exit() that skips GTK's shutdown.
            Posix.atexit (on_exit);

            // And the one that skips atexit too. When the connection to the
            // compositor drops, GTK3 logs "Error reading events from display"
            // and calls _exit(1): no atexit handler runs and no signal is
            // raised, so a log hook is the only thing left before the process is
            // gone. Measured: without it, a session ending under the app leaves
            // the mode block on disk.
            //
            // A *writer*, not g_log_set_handler(). GDK logs through
            // g_log_structured, which does not consult per-domain legacy
            // handlers — the two paths produce visibly different output, one
            // timestamped and one not, which is how this was pinned down. The
            // writer delegates to the default for everything, so logging is
            // otherwise unchanged.
            //
            // Matching on a GTK message is brittle, and deliberately additive:
            // if the wording changes we are back to the next run's
            // cleanup_stale_state() reaping the file, which is where this case
            // has always landed.
            Log.set_writer_func (on_log_written);
        }

        /**
         * A healthy process being asked to stop. Safe to do the full job.
         */
        private static void on_termination (int sig) {
            PlatformRegistry.cleanup_stale_state ();
            Posix.signal (sig, (Posix.sighandler_t) null);
            Posix.raise (sig);
        }

        /**
         * A process that has already gone wrong. Only signal-safe calls, and
         * only over data that was collected long before now.
         */
        private static void on_crash (int sig) {
            if (!in_handler) {
                in_handler = true;
                emergency_reset ();
            }

            Posix.signal (sig, (Posix.sighandler_t) null);
            Posix.raise (sig);
        }

        /**
         * exit() rather than a signal — GDK's response to losing the display.
         *
         * The ordinary cleanup has usually run by the time this fires, and both
         * paths are safe to run twice: unlinking a file that is not there and
         * asking a window manager for a mode it is already in are both no-ops.
         */
        private static void on_exit () {
            if (in_handler) return;
            in_handler = true;
            emergency_reset ();
        }

        /**
         * Every structured log line passes through here, and one of them means
         * GTK is about to _exit() because the display went away.
         *
         * Delegates to the default writer in every case, so what the user sees
         * is unchanged — including the message explaining why the app vanished.
         */
        private static LogWriterOutput on_log_written (LogLevelFlags level, LogField[] fields) {
            if (!in_handler && mentions_lost_display (fields)) {
                in_handler = true;
                emergency_reset ();
            }
            return Log.writer_default (level, fields);
        }

        private static bool mentions_lost_display (LogField[] fields) {
            foreach (var field in fields) {
                if (field.key != "MESSAGE") continue;
                var text = (string?) field.value;
                if (text != null && text.contains ("Error reading events from display"))
                    return true;
            }
            return false;
        }

        /**
         * Unlink what we wrote, then hand the keyboard back.
         *
         * unlink(), fork(), execv() and _exit() are all on POSIX's list of
         * functions a signal handler may call. Process.spawn_command_line_sync()
         * is not — it allocates, and it is exactly the kind of call that turns a
         * crash into a hang.
         *
         * The child is not waited for. waitpid() would be safe, but blocking in
         * a crash handler is not worth a tidier process table: the child is
         * reparented and finishes on its own.
         */
        private static void emergency_reset () {
            foreach (var path in files) Posix.unlink (path);

            if (reset_command.length == 0) return;

            var pid = Posix.fork ();
            if (pid != 0) return;             // parent, or fork failed

            Posix.execv (reset_command[0], reset_command);
            Posix._exit (127);                // execv only returns on failure
        }
    }
}
