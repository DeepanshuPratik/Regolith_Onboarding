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
     * KeySynthesizer builds the shell command that replays a keybinding when the
     * real window-manager binding could not be resolved.
     *
     * It is the loudest place for a silent failure in the app: ydotool given a
     * key name it does not know exits successfully and does nothing, which on
     * screen is indistinguishable from the step simply not working. So the
     * translation is worth pinning name by name.
     *
     * The command tests pin the xdotool branch, which harness.vala's main ()
     * forces by declaring the session to be X11. The ydotool branch depends on
     * ydotool being installed, so it is exercised through to_ydotool_key ()
     * directly instead of through command_for ().
     */
    public void register_key_synthesizer () {

        // ---- command_for: the whole path, spec -> replayable command ----------

        // The end-to-end case for the bare "<>" Super token. format_spec turns
        // "<>" into an empty field, which the tables map to Super_L; when that
        // lookup returned null the modifier vanished from the command and the
        // step replayed as a plain Return.
        Test.add_func ("/key-synthesizer/command/carries-every-modifier", () => {
            var synth = new KeySynthesizer ();
            var xdo = "xdotool sleep 0.5 key --clearmodifiers ";

            check_str ("<> Enter",
                       synth.command_for ("<> Enter"),        xdo + "Super_L+Return");
            check_str ("<><Shift> Enter",
                       synth.command_for ("<><Shift> Enter"), xdo + "Super_L+Shift_L+Return");
            check_str ("<> v",
                       synth.command_for ("<> v"),            xdo + "Super_L+v");
        });

        Test.add_func ("/key-synthesizer/command/uses-keysym-names", () => {
            var synth = new KeySynthesizer ();
            var xdo = "xdotool sleep 0.5 key --clearmodifiers ";

            check_str ("<> Space",
                       synth.command_for ("<> Space"),    xdo + "Super_L+space");
            check_str ("<><Shift> ?",
                       synth.command_for ("<><Shift> ?"), xdo + "Super_L+Shift_L+question");
        });

        // ---- translate: one token, tables first then keysyms ------------------

        // The bug this pins: remontoireSymToKey covers modifiers and glyphs only,
        // so any ordinary key misses it. Using that miss directly handed null to
        // the command builder, which dropped the token — and a dropped modifier
        // is a command that fires the wrong shortcut rather than none at all.
        Test.add_func ("/key-synthesizer/translate/unknown-token-survives", () => {
            var synth = new KeySynthesizer ();
            check_str ("F5",       synth.translate ("F5", false),       "F5");
            check_str ("v",        synth.translate ("v", false),        "v");
            check_str ("XF86Mail", synth.translate ("XF86Mail", false), "XF86Mail");
        });

        Test.add_func ("/key-synthesizer/translate/tables-take-precedence", () => {
            var synth = new KeySynthesizer ();
            check_str ("bare <> token", synth.translate ("", false),      "Super_L");
            check_str ("Shift",         synth.translate ("Shift", false), "Shift_L");
            check_str ("Enter",         synth.translate ("Enter", false), "Return");
            // Not in the symbol table, so it falls through to the keysym table
            // rather than passing through as the capitalised "Space".
            check_str ("Space",         synth.translate ("Space", false), "space");
        });

        // ---- to_ydotool_key: X11 keysym name -> Linux input-event name --------

        Test.add_func ("/key-synthesizer/ydotool/named-keys", () => {
            var synth = new KeySynthesizer ();
            check_str ("Return",    synth.to_ydotool_key ("Return"),    "KEY_ENTER");
            check_str ("space",     synth.to_ydotool_key ("space"),     "KEY_SPACE");
            check_str ("Escape",    synth.to_ydotool_key ("Escape"),    "KEY_ESC");
            check_str ("Tab",       synth.to_ydotool_key ("Tab"),       "KEY_TAB");
            check_str ("BackSpace", synth.to_ydotool_key ("BackSpace"), "KEY_BACKSPACE");
            check_str ("Print",     synth.to_ydotool_key ("Print"),     "KEY_SYSRQ");
            check_str ("Left",      synth.to_ydotool_key ("Left"),      "KEY_LEFT");
        });

        Test.add_func ("/key-synthesizer/ydotool/modifiers", () => {
            var synth = new KeySynthesizer ();
            check_str ("Super_L",   synth.to_ydotool_key ("Super_L"),   "KEY_LEFTMETA");

            // Function keys used to fall through to the pass-through warning,
            // so <Alt> F4 emitted "KEY_LEFTALT+F4" — a command ydotool rejects.
            check_str ("F1",  synth.to_ydotool_key ("F1"),  "KEY_F1");
            check_str ("F4",  synth.to_ydotool_key ("F4"),  "KEY_F4");
            check_str ("F12", synth.to_ydotool_key ("F12"), "KEY_F12");
            check_str ("F24", synth.to_ydotool_key ("F24"), "KEY_F24");

            // Out of range, and not a function key at all: both must keep
            // falling through rather than inventing KEY_F0 / KEY_F99. The
            // fall-through warns, and the framework makes a warning fatal
            // unless the case says it wants one.
            Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*no ydotool name*");
            check_str ("F0", synth.to_ydotool_key ("F0"), "F0");
            Test.assert_expected_messages ();

            Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*no ydotool name*");
            check_str ("F99", synth.to_ydotool_key ("F99"), "F99");
            Test.assert_expected_messages ();

            Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*no ydotool name*");
            check_str ("Fake", synth.to_ydotool_key ("Fake"), "Fake");
            Test.assert_expected_messages ();

            // Navigation and editing keys, including the names KdeResolver
            // canonicalises PgUp/PgDown/Del onto.
            check_str ("Home",   synth.to_ydotool_key ("Home"),   "KEY_HOME");
            check_str ("End",    synth.to_ydotool_key ("End"),    "KEY_END");
            check_str ("Prior",  synth.to_ydotool_key ("Prior"),  "KEY_PAGEUP");
            check_str ("Next",   synth.to_ydotool_key ("Next"),   "KEY_PAGEDOWN");
            check_str ("Delete", synth.to_ydotool_key ("Delete"), "KEY_DELETE");
            check_str ("Insert", synth.to_ydotool_key ("Insert"), "KEY_INSERT");
            check_str ("Shift_L",   synth.to_ydotool_key ("Shift_L"),   "KEY_LEFTSHIFT");
            check_str ("Control_L", synth.to_ydotool_key ("Control_L"), "KEY_LEFTCTRL");
            check_str ("Alt_L",     synth.to_ydotool_key ("Alt_L"),     "KEY_LEFTALT");
            check_str ("Caps_Lock", synth.to_ydotool_key ("Caps_Lock"), "KEY_CAPSLOCK");
        });

        // ydotool names the physical key, so the keysym a Shift produces has to
        // be mapped back to the unshifted key it lives on: "question" is the
        // slash key, not a key of its own.
        Test.add_func ("/key-synthesizer/ydotool/punctuation-maps-to-physical-key", () => {
            var synth = new KeySynthesizer ();
            check_str ("question", synth.to_ydotool_key ("question"), "KEY_SLASH");
            check_str ("slash",    synth.to_ydotool_key ("slash"),    "KEY_SLASH");
            check_str ("exclam",   synth.to_ydotool_key ("exclam"),   "KEY_1");
            check_str ("plus",     synth.to_ydotool_key ("plus"),     "KEY_EQUAL");
            check_str ("period",   synth.to_ydotool_key ("period"),   "KEY_DOT");
        });

        // Letters and digits are not in the switch at all; they are derived, and
        // the letter has to be upper-cased to name a KEY_ constant that exists.
        Test.add_func ("/key-synthesizer/ydotool/letters-and-digits-are-derived", () => {
            var synth = new KeySynthesizer ();
            check_str ("x", synth.to_ydotool_key ("x"), "KEY_X");
            check_str ("v", synth.to_ydotool_key ("v"), "KEY_V");
            check_str ("2", synth.to_ydotool_key ("2"), "KEY_2");
            check_str ("0", synth.to_ydotool_key ("0"), "KEY_0");
        });
    }
}
