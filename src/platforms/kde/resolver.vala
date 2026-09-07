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
     * What a key is really bound to on KDE, read out of kglobalshortcutsrc.
     *
     * KDE keeps its global shortcuts in one INI file written by KConfig, one
     * group per component, one entry per action:
     *
     *     [kwin]
     *     Window Maximize=Meta+PgUp,Meta+PgUp,Maximize Window
     *     Show Desktop=Meta+D\tCtrl+F12,none,Show Desktop
     *     Switch to Desktop 2=none,,Switch to Desktop 2
     *
     * Three comma-separated fields: the shortcuts in force, the defaults, and
     * the name the user is shown. Alternatives within the first field are
     * separated by a tab, which KConfig escapes. `none` means deliberately
     * unbound, and is a normal answer about a working desktop rather than an
     * absence.
     *
     * Read with KeyFile rather than by hand — it is the same INI dialect
     * branding.conf uses, and one parser is enough.
     *
     * Like GNOME, this is indexed action-to-key while the contract is asked
     * key-to-action, so the whole table is read once and inverted into the
     * canonical form below. Cheap, and cached for the life of the process.
     *
     * ## The canonical form
     *
     * `<sorted modifiers>|<keysym>`, e.g. `Control+Mod4|Left`.
     *
     * Sorted, because KDE writes `Meta+Ctrl+Left` where a workflow says
     * `<Ctrl><> Left`: the same shortcut, in a different order, and comparing
     * the strings as written would call them different. Reduced to sway's
     * modifier vocabulary and to keysyms because that is what KeySpec already
     * produces for the workflow side — so a spec the sanitiser would reject
     * cannot match anything here either.
     *
     * ## Honesty about testing
     *
     * This platform was written without a Plasma machine to try it on. What can
     * be held to account without one is the parsing, and tests/test_kde_bindings
     * does: the entry format, Qt's key names, and the agreement between the two
     * sides of the comparison. The part that remains unverified is whether
     * KWin's own shortcuts all live in this file — some are KWin scripts and
     * some are application-level — so an UNBOUND from here means "nothing in
     * kglobalshortcutsrc claims this key", which is the honest limit of what
     * the file can say.
     */
    public class KdeResolver : GLib.Object, BindingResolver {

        private const string FILENAME = "kglobalshortcutsrc";

        /** KConfig's own bookkeeping, not an action. */
        private const string INTERNAL_PREFIX = "_k_";

        /** KDE's word for "this action deliberately has no shortcut". */
        private const string UNBOUND_VALUE = "none";

        // canonical accelerator -> the name the user would recognise.
        private static HashTable<string, string>? table = null;

        // Distinguishes "read it, found nothing" from "never read it", which is
        // the UNBOUND/UNKNOWN distinction the contract turns on.
        private static bool table_is_usable = false;

        public bool available () {
            return FileUtils.test (path (), FileTest.EXISTS);
        }

        public string unavailable_reason () {
            return available () ? ""
                : "KDE's shortcut file (%s) is not there to read, so this desktop's bindings are unknown.".printf (path ());
        }

        public BindingLookup resolve (string key_id, out string command) {
            command = "";

            var wanted = canonical_spec (key_id);
            if (wanted == null) return BindingLookup.UNKNOWN;

            load_once ();
            if (!table_is_usable) return BindingLookup.UNKNOWN;

            var found = table.lookup (wanted);
            if (found == null) return BindingLookup.UNBOUND;

            command = found;
            return BindingLookup.BOUND;
        }

        private static string path () {
            return Path.build_filename (Environment.get_user_config_dir (), FILENAME);
        }

        private static void load_once () {
            if (table != null) return;

            table = new HashTable<string, string> (str_hash, str_equal);

            var keyfile = new KeyFile ();
            try {
                keyfile.load_from_file (path (), KeyFileFlags.NONE);
            } catch (Error e) {
                // No file, or one we cannot parse. Either way we have not
                // consulted the desktop, which is not the same as finding the
                // key unbound.
                message ("kde: cannot read %s (%s); bindings are unknown", path (), e.message);
                return;
            }

            foreach (var group in keyfile.get_groups ()) {
                string[] keys;
                try {
                    keys = keyfile.get_keys (group);
                } catch (Error e) {
                    continue;
                }

                foreach (var action in keys) {
                    if (action.has_prefix (INTERNAL_PREFIX)) continue;

                    string value;
                    try {
                        value = keyfile.get_string (group, action);
                    } catch (Error e) {
                        continue;
                    }

                    var label = friendly_name_in (value) ?? action;
                    foreach (var accel in accels_in (value)) {
                        var canonical = canonical_accel (accel);
                        // First writer wins: kglobalshortcutsrc can carry the
                        // same combination twice, and reporting the first is at
                        // least stable between runs.
                        if (canonical != null && table.lookup (canonical) == null) {
                            table.insert (canonical, "%s: %s".printf (group, label));
                        }
                    }
                }
            }

            table_is_usable = true;
        }

        /**
         * The shortcuts actually in force in an entry, as KDE writes them.
         *
         * internal: the parsing is the part of this class that can be tested
         * without a Plasma session, so the suite reaches it directly.
         */
        internal static string[] accels_in (string entry_value) {
            // Three fields at most, because the friendly name may contain a
            // comma of its own and splitting on every comma would truncate it.
            var fields = entry_value.split (",", 3);
            if (fields.length == 0) return {};

            var shortcuts = fields[0].strip ();
            if (shortcuts.length == 0 || shortcuts.down () == UNBOUND_VALUE) return {};

            // KConfig escapes the separator; a file written by hand may hold a
            // real tab instead.
            string[] result = {};
            foreach (var part in shortcuts.replace ("\\t", "\t").split ("\t")) {
                var accel = part.strip ();
                if (accel.length > 0 && accel.down () != UNBOUND_VALUE) result += accel;
            }
            return result;
        }

        /** The name the user would recognise, or null when the entry has none. */
        internal static string? friendly_name_in (string entry_value) {
            var fields = entry_value.split (",", 3);
            if (fields.length < 3) return null;
            var name = fields[2].strip ();
            return name.length > 0 ? name : null;
        }

        /**
         * One KDE accelerator in the canonical form, or null when it is not a
         * binding at all.
         */
        internal static string? canonical_accel (string accel) {
            var trimmed = accel.strip ();
            if (trimmed.length == 0 || trimmed.down () == UNBOUND_VALUE) return null;

            string[] mods = {};
            string key = "";

            var tokens = trimmed.split ("+");
            for (int i = 0; i < tokens.length; i++) {
                var token = tokens[i].strip ();
                if (token.length == 0) continue;

                if (i == tokens.length - 1) {
                    key = qt_key_to_keysym (token);
                } else {
                    var mod = qt_modifier_to_mask (token);
                    if (mod == null) return null;  // not a modifier we understand
                    mods += mod;
                }
            }

            if (key.length == 0) return null;
            return join_canonical (mods, key);
        }

        /**
         * A workflow's own key spec in the same form, or null when the spec is
         * not one this app would ever write.
         *
         * Goes through KeySpec.format_spec_for_mode so that the two sides cannot
         * drift: that method already produces `Mod4+Shift+Return`, which is this
         * form modulo sorting.
         */
        internal static string? canonical_spec (string key_id) {
            var spec = new KeySpec ();
            var formatted = spec.format_spec_for_mode (key_id);
            if (formatted.length == 0) return null;

            var parts = formatted.split ("+");
            if (parts.length == 0) return null;

            string[] mods = {};
            for (int i = 0; i < parts.length - 1; i++) mods += parts[i];
            return join_canonical (mods, parts[parts.length - 1]);
        }

        // Sorted so that the order a desktop happens to write its modifiers in
        // cannot make two spellings of one shortcut look like two shortcuts.
        private static string join_canonical (string[] mods, string key) {
            var sorted = mods;
            for (int i = 1; i < sorted.length; i++) {
                for (int j = i; j > 0 && strcmp (sorted[j - 1], sorted[j]) > 0; j--) {
                    var swap = sorted[j - 1];
                    sorted[j - 1] = sorted[j];
                    sorted[j] = swap;
                }
            }
            return string.joinv ("+", sorted) + "|" + key;
        }

        // Qt's modifier names, in sway's vocabulary — the one KeySpec emits.
        private static string? qt_modifier_to_mask (string token) {
            switch (token.down ()) {
                case "meta":
                case "super":   return "Mod4";
                case "ctrl":
                case "control": return "Control";
                case "alt":     return "Mod1";
                case "shift":   return "Shift";
                default:        return null;
            }
        }

        /**
         * Qt's key names are not keysyms, and the difference is not cosmetic:
         * "PgDown" is "Next", and a comparison that skipped this would report
         * every paging shortcut as unbound.
         */
        private static string qt_key_to_keysym (string token) {
            switch (token.down ()) {
                case "pgdown":
                case "pagedown": return "Next";
                case "pgup":
                case "pageup":   return "Prior";
                case "esc":      return "Escape";
                case "del":      return "Delete";
                case "ins":      return "Insert";
                case "backspace":
                case "back":     return "BackSpace";
                case "space":    return "space";
                case "enter":
                case "return":   return "Return";
                case "tab":      return "Tab";
                case "up":       return "Up";
                case "down":     return "Down";
                case "left":     return "Left";
                case "right":    return "Right";
                case "home":     return "Home";
                case "end":      return "End";
                case "print":    return "Print";
                default:         break;
            }

            // A single letter is uppercase in Qt's spelling and lowercase in a
            // keysym; anything else (F1, a digit) is already the same in both.
            if (token.length == 1 && token[0].isalpha ()) return token.down ();
            return token;
        }
    }
}
