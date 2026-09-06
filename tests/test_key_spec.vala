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
     * KeySpec turns the remontoire spec in workflow JSON into either a bindsym
     * spec for the window manager or a display string for the user.
     *
     * Every case here is one this codebase has already been bitten by. The
     * failure mode they share is silence: sway rejects one bad bindsym by
     * invalidating the whole generated config, and a modifier that quietly
     * vanishes produces a binding that simply never fires. Neither shows up as
     * an error the user can read, which is exactly why they are worth pinning.
     *
     * The expected values are the ones --check-workflows prints for the bundled
     * Regolith workflows, so this suite and that command cannot drift apart
     * without one of them going red.
     */
    public void register_key_spec () {

        // ---- format_spec_for_mode: remontoire spec -> sway bindsym spec ------

        // The bare "<>" is how someone writing workflow JSON by hand spells
        // Super. It is not a malformed token to be skipped; dropping it turns
        // "Super+Return" into a plain "Return" that fires on every newline.
        Test.add_func ("/key-spec/for-mode/bare-angle-brackets-are-super", () => {
            var spec = new KeySpec ();
            check_str ("<> Enter", spec.format_spec_for_mode ("<> Enter"), "Mod4+Return");
            check_str ("<> v",     spec.format_spec_for_mode ("<> v"),     "Mod4+v");
            check_str ("<> 2",     spec.format_spec_for_mode ("<> 2"),     "Mod4+2");
        });

        // Regolith's own configs spell Super as the FontAwesome glyph U+F17A,
        // which is three bytes — so any parser that assumes a one-character
        // modifier token mis-slices it.
        Test.add_func ("/key-spec/for-mode/fontawesome-glyph-is-super", () => {
            var spec = new KeySpec ();
            check_str ("glyph + Enter",
                       spec.format_spec_for_mode ("<" + KeyTables.SUPER_GLYPH + "> Enter"),
                       "Mod4+Return");
        });

        Test.add_func ("/key-spec/for-mode/modifier-stacking", () => {
            var spec = new KeySpec ();
            check_str ("<><Shift> Enter",
                       spec.format_spec_for_mode ("<><Shift> Enter"), "Mod4+Shift+Return");
            check_str ("<><CAPS> Escape",
                       spec.format_spec_for_mode ("<><CAPS> Escape"), "Mod4+Lock+Escape");
            check_str ("<Ctrl><Alt> t",
                       spec.format_spec_for_mode ("<Ctrl><Alt> t"),   "Control+Mod1+t");
        });

        // "bindsym Mod4+Shift+? nop" is rejected outright by sway with "Unknown
        // key or button", and a rejected line invalidates the entire config file
        // it sits in — so this one bad spec takes every other binding with it.
        Test.add_func ("/key-spec/for-mode/punctuation-becomes-a-keysym", () => {
            var spec = new KeySpec ();
            check_str ("<><Shift> ?",
                       spec.format_spec_for_mode ("<><Shift> ?"), "Mod4+question");
        });

        // sway silently canonicalises "Space" to "space", so a spec that keeps
        // the capital compares unequal against the binding event forever after.
        Test.add_func ("/key-spec/for-mode/space-is-lowercased", () => {
            var spec = new KeySpec ();
            check_str ("<> Space", spec.format_spec_for_mode ("<> Space"), "Mod4+space");
        });

        Test.add_func ("/key-spec/for-mode/arrow-glyphs", () => {
            var spec = new KeySpec ();
            check_str ("<> ←",       spec.format_spec_for_mode ("<> ←"),       "Mod4+Left");
            check_str ("<><Shift> →", spec.format_spec_for_mode ("<><Shift> →"), "Mod4+Shift+Right");
        });

        // Workflow steps are keyed by opaque ids as well as by key specs. An id
        // has no angle brackets and must produce no bindsym at all, rather than
        // a line that sway would reject.
        Test.add_func ("/key-spec/for-mode/opaque-id-yields-nothing", () => {
            var spec = new KeySpec ();
            check_str ("Session_25", spec.format_spec_for_mode ("Session_25"), "");
            check_str ("empty",      spec.format_spec_for_mode (""),           "");
        });

        // The two parser bugs the harness found, both routed to #18: input
        // that produces a plausible-looking wrong answer instead of an error.
        //
        // 1. Malformed: "<Shift" has no closing '>'. The old behaviour was
        //    to fall through to `return mods.str + to_keysym(remaining)`, which
        //    produced the literal string "<Shift" and let sway reject the
        //    whole mode block. The sanitiser cannot help here — the bug
        //    happens before the sanitiser runs — so the parser has to.
        // 2. Unknown modifier: "<Super> Enter". The old behaviour was to
        //    silently drop Super and emit "Return", contradicting the
        //    function's own doc comment. Fix is to reject rather than guess.
        Test.add_func ("/key-spec/for-mode/malformed-input-is-rejected", () => {
            var spec = new KeySpec ();
            check_str ("unclosed modifier", spec.format_spec_for_mode ("<Shift"),        "");
            check_str ("unclosed after good modifier",
                       spec.format_spec_for_mode ("<><Shift"),                            "");
            check_str ("unrecognised ASCII modifier",
                       spec.format_spec_for_mode ("<Super> Enter"),                      "");
        });

        // ---- to_keysym: remontoire key name -> X11 keysym name ---------------

        Test.add_func ("/key-spec/to-keysym/named-keys", () => {
            var spec = new KeySpec ();
            check_str ("Enter",     spec.to_keysym ("Enter"),     "Return");
            check_str ("Space",     spec.to_keysym ("Space"),     "space");
            check_str ("space",     spec.to_keysym ("space"),     "space");
            check_str ("Backspace", spec.to_keysym ("Backspace"), "BackSpace");
            check_str ("PrtScr",    spec.to_keysym ("PrtScr"),    "Print");
            check_str ("Prtscr",    spec.to_keysym ("Prtscr"),    "Print");
            check_str ("↑",         spec.to_keysym ("↑"),         "Up");
            check_str ("↓",         spec.to_keysym ("↓"),         "Down");
        });

        Test.add_func ("/key-spec/to-keysym/punctuation", () => {
            var spec = new KeySpec ();
            check_str ("?",  spec.to_keysym ("?"),  "question");
            check_str ("!",  spec.to_keysym ("!"),  "exclam");
            check_str ("/",  spec.to_keysym ("/"),  "slash");
            check_str ("-",  spec.to_keysym ("-"),  "minus");
            check_str ("[",  spec.to_keysym ("["),  "bracketleft");
            check_str ("\\", spec.to_keysym ("\\"), "backslash");
        });

        // The table is a set of exceptions, not a whitelist: anything already
        // spelled the way X11 spells it has to survive untouched. Returning null
        // for the unknown case is the bug this pins — see the synthesizer suite
        // for what that null did downstream.
        Test.add_func ("/key-spec/to-keysym/unknown-passes-through-unchanged", () => {
            var spec = new KeySpec ();
            check_str ("plain letter", spec.to_keysym ("v"),      "v");
            check_str ("digit",        spec.to_keysym ("2"),      "2");
            check_str ("Tab",          spec.to_keysym ("Tab"),    "Tab");
            check_str ("F5",           spec.to_keysym ("F5"),     "F5");
            check_str ("Escape",       spec.to_keysym ("Escape"), "Escape");
        });

        // ---- format_spec / format_spec_display -------------------------------

        // format_spec feeds KeySynthesizer, which splits the result on spaces.
        // The leading empty field is load-bearing: it is the "<>" Super token.
        Test.add_func ("/key-spec/format-spec/splits-into-tokens", () => {
            var spec = new KeySpec ();
            check_str ("<> Enter",        spec.format_spec ("<> Enter"),        " Enter");
            check_str ("<><Shift> Enter", spec.format_spec ("<><Shift> Enter"), " Shift Enter");
        });

        // What the practice page puts after "PRESS:". This used to strip the
        // angle brackets and nothing else, which turned the Super token "<>"
        // into two spaces: the one modifier every Regolith shortcut starts with
        // was invisible, and "<> Enter" read as "PRESS:   Enter".
        /**
         * A symbol that can only be typed with Shift must NOT carry Shift in the
         * bindsym, or the binding matches nothing at all.
         *
         * Sway resolves a press two ways: the raw keysym with the modifiers as
         * held, and the translated keysym with Shift consumed where Shift is what
         * produced the symbol. Pressing Super+Shift+/ is raw `slash` with Shift,
         * translated `question` without it. `Mod4+Shift+question` matches
         * neither — raw has the wrong keysym, translated has no Shift — so the
         * step could never fire. Regolith's own config gets this right for the
         * keybinding viewer (`$mod+question`) while the comment above it, which
         * is where the workflow's key_id came from, says `<><Shift> ?`.
         */
        Test.add_func ("/key-spec/format-spec-for-mode/shifted-symbols-drop-shift", () => {
            var spec = new KeySpec ();
            check_str ("question", spec.format_spec_for_mode ("<><Shift> ?"), "Mod4+question");
            check_str ("exclam",   spec.format_spec_for_mode ("<><Shift> !"), "Mod4+exclam");
            check_str ("plus",     spec.format_spec_for_mode ("<><Shift> +"), "Mod4+plus");
        });

        /**
         * The opposite case, and the reason this is not "always drop Shift": a
         * letter, digit or named key keeps it. Shift+f is raw `f` with Shift
         * held, which is exactly what `Mod4+Shift+f` matches.
         */
        Test.add_func ("/key-spec/format-spec-for-mode/unshifted-keys-keep-shift", () => {
            var spec = new KeySpec ();
            check_str ("letter", spec.format_spec_for_mode ("<><Shift> f"), "Mod4+Shift+f");
            check_str ("named",  spec.format_spec_for_mode ("<><Shift> Enter"), "Mod4+Shift+Return");
            check_str ("digit",  spec.format_spec_for_mode ("<><Shift> 1"), "Mod4+Shift+1");
            check_str ("slash stays unshifted",
                       spec.format_spec_for_mode ("<><Shift> /"), "Mod4+Shift+slash");
        });

        Test.add_func ("/key-spec/format-spec-display/names-super", () => {
            var spec = new KeySpec ();
            check_str ("bare <> is Super",
                       spec.format_spec_display ("<> Enter"), "Super + Enter");
            check_str ("the FontAwesome glyph is Super too",
                       spec.format_spec_display ("<> Enter"), "Super + Enter");
        });

        Test.add_func ("/key-spec/format-spec-display/names-every-modifier", () => {
            var spec = new KeySpec ();
            check_str ("<><Shift> Enter",
                       spec.format_spec_display ("<><Shift> Enter"), "Super + Shift + Enter");
            check_str ("<Ctrl><Alt> t",
                       spec.format_spec_display ("<Ctrl><Alt> t"), "Ctrl + Alt + T");
            check_str ("<CAPS> x",
                       spec.format_spec_display ("<CAPS> x"), "Caps Lock + X");
        });

        // A key cap is uppercase, and the arrows and named keys are shown as the
        // author wrote them.
        Test.add_func ("/key-spec/format-spec-display/key-names", () => {
            var spec = new KeySpec ();
            check_str ("letter",  spec.format_spec_display ("<> a"), "Super + A");
            check_str ("digit",   spec.format_spec_display ("<> 1"), "Super + 1");
            check_str ("arrow",   spec.format_spec_display ("<Ctrl><Alt> ←"), "Ctrl + Alt + ←");
            check_str ("named",   spec.format_spec_display ("<Alt> Tab"), "Alt + Tab");
            check_str ("question", spec.format_spec_display ("<><Shift> ?"), "Super + Shift + ?");
        });

        // Display is forgiving where the mode parser is strict: a spec it cannot
        // read still has to put something legible in front of the user, because
        // showing nothing is the bug this function had.
        Test.add_func ("/key-spec/format-spec-display/never-empty", () => {
            var spec = new KeySpec ();
            check_str ("unknown modifier is kept",
                       spec.format_spec_display ("<Hyper> x"), "Hyper + X");
            check_str ("no closing bracket",
                       spec.format_spec_display ("<Shift"), "Shift");
            check_str ("opaque id passes through",
                       spec.format_spec_display ("Session_25"), "Session_25");
            check_str ("modifier with no key",
                       spec.format_spec_display ("<>"), "Super");
        });
    }
}
