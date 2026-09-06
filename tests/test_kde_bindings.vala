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
     * Reading KDE's kglobalshortcutsrc.
     *
     * These cover the whole of KdeResolver that can be covered without KWin: the
     * entry format, Qt's key names, and the canonical form both sides of the
     * comparison are reduced to. That matters more here than elsewhere in this
     * suite, because the platform this belongs to was written without a Plasma
     * machine to try it on — the parsing is the part that can be held to
     * account, so it is.
     *
     * The canonical form is "<sorted modifiers>|<keysym>": sorted because KDE
     * writes Meta+Ctrl+Left where a workflow says <Ctrl><Super> Left and the two
     * mean the same shortcut, and a comparison of unsorted strings would call
     * them different.
     */

    /** Qt spells the Super key "Meta"; ours is sway's Mod4. */
    private void test_kde_accel_super () {
        check_str ("Meta+Return", KdeResolver.canonical_accel ("Meta+Return"), "Mod4|Return");
    }

    /** Modifiers are sorted, so the order KDE happens to write them in is irrelevant. */
    private void test_kde_accel_modifier_order_is_irrelevant () {
        check_str ("Meta+Ctrl+Left", KdeResolver.canonical_accel ("Meta+Ctrl+Left"),
                   "Control+Mod4|Left");
        check_str ("Ctrl+Meta+Left", KdeResolver.canonical_accel ("Ctrl+Meta+Left"),
                   "Control+Mod4|Left");
    }

    /** Alt is Mod1, as it is everywhere else in this codebase. */
    private void test_kde_accel_alt_and_shift () {
        check_str ("Alt+Shift+Tab", KdeResolver.canonical_accel ("Alt+Shift+Tab"),
                   "Mod1+Shift|Tab");
    }

    /** Qt's key names are not keysyms, and the difference is not cosmetic. */
    private void test_kde_accel_qt_key_names () {
        check_str ("PgDown", KdeResolver.canonical_accel ("Meta+PgDown"), "Mod4|Next");
        check_str ("PgUp",   KdeResolver.canonical_accel ("Meta+PgUp"),   "Mod4|Prior");
        check_str ("Esc",    KdeResolver.canonical_accel ("Esc"),         "|Escape");
        check_str ("Space",  KdeResolver.canonical_accel ("Meta+Space"),  "Mod4|space");
        check_str ("Del",    KdeResolver.canonical_accel ("Meta+Del"),    "Mod4|Delete");
        check_str ("Enter",  KdeResolver.canonical_accel ("Meta+Enter"),  "Mod4|Return");
    }

    /** A letter is written uppercase by Qt and lowercase by us. */
    private void test_kde_accel_letters_are_lowercased () {
        check_str ("Meta+D", KdeResolver.canonical_accel ("Meta+D"), "Mod4|d");
    }

    /** KDE's word for "deliberately not bound" is not a shortcut. */
    private void test_kde_accel_none_is_not_a_binding () {
        check_str ("none",  KdeResolver.canonical_accel ("none"), null);
        check_str ("empty", KdeResolver.canonical_accel (""),     null);
        check_str ("blank", KdeResolver.canonical_accel ("   "),  null);
    }

    /**
     * An entry is `shortcuts,default,friendly name`, with alternative shortcuts
     * separated by an escaped tab.
     */
    private void test_kde_entry_yields_every_alternative () {
        var accels = KdeResolver.accels_in ("Meta+D\\tCtrl+F12,none,Show Desktop");
        check_int ("two alternatives", accels.length, 2);
        if (accels.length == 2) {
            check_str ("first",  accels[0], "Meta+D");
            check_str ("second", accels[1], "Ctrl+F12");
        }
    }

    /** A real tab, in case KConfig wrote one rather than the escape. */
    private void test_kde_entry_accepts_a_real_tab () {
        var accels = KdeResolver.accels_in ("Meta+D\tCtrl+F12,none,Show Desktop");
        check_int ("two alternatives", accels.length, 2);
    }

    /** An unbound action contributes no shortcuts at all. */
    private void test_kde_entry_unbound_yields_nothing () {
        check_int ("none", KdeResolver.accels_in ("none,none,Switch to Desktop 2").length, 0);
        check_int ("empty leading field", KdeResolver.accels_in (",,Something").length, 0);
    }

    /**
     * The friendly name is what the user is shown, and it is the one field that
     * can legitimately contain a comma — so the value is split into three parts
     * at most, never on every comma.
     */
    private void test_kde_entry_friendly_name_keeps_its_commas () {
        check_str ("plain",
                   KdeResolver.friendly_name_in ("Meta+D,none,Show Desktop"),
                   "Show Desktop");
        check_str ("comma inside the name",
                   KdeResolver.friendly_name_in ("Meta+X,none,Do this, then that"),
                   "Do this, then that");
        check_str ("no name field",
                   KdeResolver.friendly_name_in ("Meta+X"),
                   null);
    }

    /**
     * The workflow side of the comparison, reduced to the same form. Reusing
     * KeySpec means a spec the sanitiser would reject cannot match anything
     * here either.
     */
    private void test_kde_canonical_from_workflow_spec () {
        check_str ("<> Enter",          KdeResolver.canonical_spec ("<> Enter"),          "Mod4|Return");
        check_str ("<><Shift> Enter",   KdeResolver.canonical_spec ("<><Shift> Enter"),   "Mod4+Shift|Return");
        check_str ("<Ctrl><> Left",     KdeResolver.canonical_spec ("<Ctrl><> Left"),     "Control+Mod4|Left");
        check_str ("<> 2",              KdeResolver.canonical_spec ("<> 2"),              "Mod4|2");
    }

    /** And a spec that is not parseable matches nothing rather than everything. */
    private void test_kde_canonical_rejects_a_bad_spec () {
        check_str ("malformed", KdeResolver.canonical_spec ("<Shift"),     null);
        check_str ("opaque id", KdeResolver.canonical_spec ("Session_25"), null);
    }

    /**
     * The two sides meeting: what KDE writes for "Meta+Ctrl+Left" is what a
     * workflow means by "<Ctrl><> Left". If this ever stops holding, resolution
     * on KDE silently reports every key as unbound.
     */
    private void test_kde_both_sides_agree () {
        check_str ("agreement",
                   KdeResolver.canonical_accel ("Meta+Ctrl+Left"),
                   KdeResolver.canonical_spec ("<Ctrl><> Left"));
    }

    public void register_kde_bindings () {
        Test.add_func ("/kde/accel/super", test_kde_accel_super);
        Test.add_func ("/kde/accel/modifier-order", test_kde_accel_modifier_order_is_irrelevant);
        Test.add_func ("/kde/accel/alt-and-shift", test_kde_accel_alt_and_shift);
        Test.add_func ("/kde/accel/qt-key-names", test_kde_accel_qt_key_names);
        Test.add_func ("/kde/accel/letters-lowercased", test_kde_accel_letters_are_lowercased);
        Test.add_func ("/kde/accel/none-is-not-a-binding", test_kde_accel_none_is_not_a_binding);
        Test.add_func ("/kde/entry/alternatives", test_kde_entry_yields_every_alternative);
        Test.add_func ("/kde/entry/real-tab", test_kde_entry_accepts_a_real_tab);
        Test.add_func ("/kde/entry/unbound", test_kde_entry_unbound_yields_nothing);
        Test.add_func ("/kde/entry/friendly-name", test_kde_entry_friendly_name_keeps_its_commas);
        Test.add_func ("/kde/spec/canonical", test_kde_canonical_from_workflow_spec);
        Test.add_func ("/kde/spec/rejects-bad", test_kde_canonical_rejects_a_bad_spec);
        Test.add_func ("/kde/both-sides-agree", test_kde_both_sides_agree);
    }
}
