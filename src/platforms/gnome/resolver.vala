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
     * What a key is really bound to on GNOME, read out of GSettings.
     *
     * GNOME keeps its shortcuts as arrays of GTK accelerator strings — a key
     * named for the action it performs, holding zero or more accelerators that
     * trigger it: `terminal` is `['<Primary><Alt>t']`, `move-to-workspace-left`
     * is three accelerators at once, and a great many ship empty.
     *
     * The direction is the awkward part. GSettings is indexed action-to-key
     * while this contract is asked key-to-action, so there is no lookup to do:
     * the whole table is read once and walked. That is cheap enough (a few
     * hundred keys across four schemas, cached for the life of the process) and
     * it is the only way to answer the question actually being asked.
     *
     * Reports; never acts. GNOME has no `swaymsg` to run an action by name, so
     * the command handed back is documented below as an identifier rather than
     * anything runnable.
     */
    public class GnomeResolver : GLib.Object, BindingResolver {

        /**
         * The action tables scanned, in the order a match is reported.
         *
         * The first two are where a user's own shortcuts live and are the two
         * the ticket names. The last two are here so that UNBOUND means
         * something: GNOME Shell and Mutter own a large share of the default
         * bindings — the overview, the window-switcher, the tiling keys — and a
         * scan that skipped them would confidently report "this key does
         * nothing" about Super+Tab.
         */
        private const string[] ACTION_SCHEMAS = {
            "org.gnome.desktop.wm.keybindings",
            "org.gnome.settings-daemon.plugins.media-keys",
            "org.gnome.shell.keybindings",
            "org.gnome.mutter.keybindings"
        };

        private const string MEDIA_KEYS_SCHEMA = "org.gnome.settings-daemon.plugins.media-keys";

        // Relocatable: one instance per path listed in the key below, so it is
        // reached through Settings.with_path rather than by id alone.
        private const string CUSTOM_SCHEMA = MEDIA_KEYS_SCHEMA + ".custom-keybinding";
        private const string CUSTOM_LIST_KEY = "custom-keybindings";

        private KeySpec spec = new KeySpec ();

        // Built on first use and kept: GSettings does not change under us within
        // a run, and re-reading four schemas per practice step was pointless work.
        private Gee.List<GnomeBinding>? table = null;

        /**
         * Whether any of the tables exist to be read.
         *
         * The schemas are not guaranteed to be installed — this app runs on
         * desktops that are GNOME-adjacent without shipping gnome-settings-daemon
         * — and asking is not optional: constructing a GLib.Settings for a schema
         * that does not exist aborts the process rather than returning an error.
         * Every schema below is looked up through SettingsSchemaSource first for
         * that reason.
         */
        public bool available () {
            foreach (var id in ACTION_SCHEMAS) {
                if (schema_exists (id)) return true;
            }
            return false;
        }

        public string unavailable_reason () {
            return available () ? ""
                : "GNOME's keybinding schemas are not installed, so its shortcuts cannot be read.";
        }

        /**
         * command is the GSettings action name — "terminal", "close",
         * "switch-to-workspace-2" — and NOT a shell command. There is nothing on
         * GNOME that runs an action by name the way `swaymsg` runs a sway
         * command, so this is an identifier for display and logging only. The
         * paired dispatcher ignores it and replays the keystroke instead.
         */
        public BindingLookup resolve (string key_id, out string command) {
            command = "";
            if (!available ()) return BindingLookup.UNKNOWN;

            // The remontoire spec reduced to the same bindsym notation the sway
            // resolver compares against, e.g. "<><Shift> Enter" -> "Mod4+Shift+Return".
            var key_spec = spec.format_spec_for_mode (key_id);
            if (key_spec.length == 0) return BindingLookup.UNKNOWN;

            uint wanted_mods;
            string wanted_key;
            if (!parse_bindsym (key_spec, out wanted_mods, out wanted_key))
                return BindingLookup.UNKNOWN;

            foreach (var binding in bindings ()) {
                if (binding.mods != wanted_mods) continue;
                if (binding.keysym != wanted_key) continue;
                command = binding.action;
                return BindingLookup.BOUND;
            }

            // The tables were read and nothing claims this key. UNBOUND rather
            // than UNKNOWN, and the distinction is the whole reason this enum has
            // three values: on GNOME most default bindings ship empty, so "no
            // binding" is the ordinary answer about a perfectly working desktop
            // and must never reach the user as a failure.
            return BindingLookup.UNBOUND;
        }

        /**
         * Every accelerator GNOME has, flattened into one list.
         *
         * Empty entries are dropped here rather than compared and rejected later.
         * Both spellings of "no binding" occur in practice and neither is an
         * error: `switch-to-workspace-2` is the empty array `@as []` while `www`
         * is `['']`, a one-element array holding an empty string.
         */
        private Gee.List<GnomeBinding> bindings () {
            if (table != null) return table;

            var found = new Gee.ArrayList<GnomeBinding> ();

            foreach (var schema_id in ACTION_SCHEMAS) {
                var schema = lookup_schema (schema_id);
                if (schema == null) continue;

                var settings = new GLib.Settings (schema_id);
                foreach (var name in schema.list_keys ()) {
                    // Holds GSettings paths, not accelerators; read separately below.
                    if (name == CUSTOM_LIST_KEY) continue;

                    var value = settings.get_value (name);
                    if (!value.is_of_type (GLib.VariantType.STRING_ARRAY)) continue;

                    foreach (var accel in value.get_strv ()) add (found, accel, name);
                }
            }

            foreach (var custom in custom_bindings ()) found.add (custom);

            table = found;
            return table;
        }

        /**
         * The shortcuts the user added by hand in Settings.
         *
         * A relocatable schema: the list key holds object paths and each path
         * carries one name/command/binding triple. The path is checked before
         * use because Settings.with_path asserts on a malformed one, and this
         * list is whatever happens to be in the user's dconf.
         */
        private Gee.List<GnomeBinding> custom_bindings () {
            var found = new Gee.ArrayList<GnomeBinding> ();

            if (!schema_exists (MEDIA_KEYS_SCHEMA) || !schema_exists (CUSTOM_SCHEMA))
                return found;

            var media = new GLib.Settings (MEDIA_KEYS_SCHEMA);
            foreach (var path in media.get_strv (CUSTOM_LIST_KEY)) {
                if (!path.has_prefix ("/") || !path.has_suffix ("/")) continue;

                var entry = new GLib.Settings.with_path (CUSTOM_SCHEMA, path);
                var label = entry.get_string ("name");

                // Reported by its label, not by the shell command it runs. The
                // contract's command is an identifier the caller must not
                // execute, and a custom keybinding is the one case where a
                // runnable string is sitting right there to be misused.
                add (found, entry.get_string ("binding"),
                     label.length > 0 ? label : "custom keybinding");
            }
            return found;
        }

        private void add (Gee.List<GnomeBinding> into, string accel, string action) {
            uint mods;
            string keysym;
            if (!parse_accelerator (accel, out mods, out keysym)) return;
            into.add (new GnomeBinding (mods, keysym, action));
        }

        /**
         * Canonical modifier bits.
         *
         * Neither notation's own spelling survives the comparison: GNOME writes
         * Ctrl as `<Primary>` and sometimes `<Control>`, while the bindsym form
         * writes it `Control`, and Super is `<Super>` on one side and `Mod4` on
         * the other. Both sides are reduced to these bits so that matching is a
         * plain integer comparison and modifier order stops mattering.
         */
        private const uint MOD_SHIFT = 1 << 0;
        private const uint MOD_CTRL  = 1 << 1;
        private const uint MOD_ALT   = 1 << 2;
        private const uint MOD_SUPER = 1 << 3;
        private const uint MOD_CAPS  = 1 << 4;

        /**
         * Splits a GTK accelerator — "<Primary><Alt>t", "<Super>Home", "F12" —
         * into canonical modifiers and a keysym name.
         *
         * Hand-rolled rather than handed to Gtk.accelerator_parse, which looks
         * like the obvious choice and is the wrong one here. It resolves the
         * virtual modifiers through the display's keymap, so with no display
         * connection it logs a Gdk-CRITICAL and *silently drops* them:
         * "<Primary><Alt>t" comes back carrying Alt alone, which would match the
         * wrong key rather than fail. --check-workflows runs with no display at
         * all, so that path is not usable.
         *
         * Returns false for anything with no key name left, which covers both
         * spellings of an unbound action: "" and a value that is only modifiers.
         */
        private bool parse_accelerator (string accel, out uint mods, out string keysym) {
            mods = 0;
            keysym = "";

            string rest = accel.strip ();
            while (rest.has_prefix ("<")) {
                int close = rest.index_of (">");
                if (close < 0) return false;                 // malformed

                mods |= modifier_bit (rest.slice (1, close).down ());
                rest = rest.slice (close + 1, rest.length);
            }

            if (rest.length == 0) return false;
            keysym = rest.down ();
            return true;
        }

        /**
         * Splits the bindsym notation KeySpec produces — "Mod4+Shift+Return" —
         * the same way, so both sides of the comparison end up in one form.
         *
         * The vocabulary here is fixed by KeySpec.format_spec_for_mode rather
         * than by anything GNOME does; it emits only these five modifier names.
         */
        private bool parse_bindsym (string key_spec, out uint mods, out string keysym) {
            mods = 0;
            keysym = "";

            var parts = key_spec.split ("+");
            if (parts.length == 0) return false;

            for (int i = 0; i < parts.length - 1; i++)
                mods |= modifier_bit (parts[i].down ());

            keysym = parts[parts.length - 1].down ();
            return keysym.length > 0;
        }

        /**
         * One modifier name, whichever notation it arrived in.
         *
         * An unrecognised name contributes nothing, which is deliberate: Mod2,
         * Mod3 and Mod5 carry no agreed meaning across keyboards, and `<Release>`
         * is not a modifier at all. Treating them as significant would produce
         * mismatches nobody could explain; ignoring them means such a binding
         * simply never matches, which is the honest outcome.
         */
        private uint modifier_bit (string name) {
            switch (name) {
                case "shift":                        return MOD_SHIFT;
                case "primary":
                case "control":
                case "ctrl":                         return MOD_CTRL;
                // Meta is conventionally Mod1 on Linux keymaps, alongside Alt.
                case "alt":
                case "meta":
                case "mod1":                         return MOD_ALT;
                case "super":
                case "hyper":
                case "mod4":                         return MOD_SUPER;
                case "lock":
                case "caps":                         return MOD_CAPS;
                default:                             return 0;
            }
        }

        private bool schema_exists (string id) { return lookup_schema (id) != null; }

        private GLib.SettingsSchema? lookup_schema (string id) {
            var source = GLib.SettingsSchemaSource.get_default ();
            if (source == null) return null;
            return source.lookup (id, true);
        }
    }

    /** One accelerator, reduced to the form resolve() compares against. */
    private class GnomeBinding : GLib.Object {

        public uint   mods   { get; private set; }
        public string keysym { get; private set; }
        public string action { get; private set; }

        public GnomeBinding (uint mods, string keysym, string action) {
            this.mods = mods;
            this.keysym = keysym;
            this.action = action;
        }
    }
}
