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
     * The lookup tables behind the observers and the synthesizer.
     *
     * KeyTables.match () is not covered: it takes a Gdk.EventKey, which means a
     * real key event from a real display. The tables themselves are plain data
     * and are where the interesting mistakes live anyway.
     */
    public void register_key_tables () {

        // Super arrives written two ways and both have to resolve. When only the
        // glyph was registered, a hand-written "<>" fell through to null and the
        // modifier was dropped — the binding then matched on the bare key.
        Test.add_func ("/key-tables/super-has-two-spellings", () => {
            var tables = new KeyTables ();

            check_int ("modifierMasks[\"\"]",
                       tables.modifierMasks[""],
                       (int) Gdk.ModifierType.SUPER_MASK);
            check_int ("modifierMasks[SUPER_GLYPH]",
                       tables.modifierMasks[KeyTables.SUPER_GLYPH],
                       (int) Gdk.ModifierType.SUPER_MASK);

            check_str ("remontoireSymToKey[\"\"]",
                       tables.remontoireSymToKey[""], "Super_L");
            check_str ("remontoireSymToKey[SUPER_GLYPH]",
                       tables.remontoireSymToKey[KeyTables.SUPER_GLYPH], "Super_L");
        });

        Test.add_func ("/key-tables/modifier-masks", () => {
            var tables = new KeyTables ();
            check_int ("Shift", tables.modifierMasks["Shift"], (int) Gdk.ModifierType.SHIFT_MASK);
            check_int ("Alt",   tables.modifierMasks["Alt"],   (int) Gdk.ModifierType.MOD1_MASK);
            check_int ("Ctrl",  tables.modifierMasks["Ctrl"],  (int) Gdk.ModifierType.CONTROL_MASK);
            check_int ("CAPS",  tables.modifierMasks["CAPS"],  (int) Gdk.ModifierType.LOCK_MASK);
        });

        Test.add_func ("/key-tables/remontoire-symbols", () => {
            var tables = new KeyTables ();
            check_str ("Shift", tables.remontoireSymToKey["Shift"], "Shift_L");
            check_str ("Alt",   tables.remontoireSymToKey["Alt"],   "Alt_L");
            check_str ("Ctrl",  tables.remontoireSymToKey["Ctrl"],  "Control_L");
            check_str ("CAPS",  tables.remontoireSymToKey["CAPS"],  "Caps_Lock");
            check_str ("Enter", tables.remontoireSymToKey["Enter"], "Return");
            check_str ("←",     tables.remontoireSymToKey["←"],     "Left");
        });

        // This table covers modifiers and glyphs only, so a miss is normal rather
        // than exceptional. Pinning the null is the point: it is what every caller
        // has to have a fallback for.
        Test.add_func ("/key-tables/miss-returns-null", () => {
            var tables = new KeyTables ();
            check_str ("plain letter", tables.remontoireSymToKey["v"],     null);
            check_str ("Space",        tables.remontoireSymToKey["Space"], null);
        });
    }
}
