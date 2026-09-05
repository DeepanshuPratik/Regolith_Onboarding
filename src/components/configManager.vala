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
using Gtk;
using Gee;

namespace linux_onboarding{

  public class configManager{

    public configManager(){

    }

    public  string format_spec (string raw_keybinding) {
        // TODO: this won't work for keybindings with < > characters
        return raw_keybinding
                .replace ("<", "")
                .replace (">", " ")
                .replace ("  ", " ");
    }
    public  string format_spec_display (string raw_keybinding) {
        // TODO: this won't work for keybindings with < > characters
        return raw_keybinding
                .replace ("<", " ")
                .replace (">", " ");
    }

    public string format_spec_for_mode (string raw_keybinding) {
        // Opaque IDs like "Session_25" contain no angle brackets — skip.
        if (!raw_keybinding.contains ("<")) return "";

        // Parse remontoire format: zero or more <modifier> tokens followed
        // by a space and the key name.
        // e.g. "<Super> Enter"     -> "Mod4+Return"
        //      "<Super><Shift> Enter" -> "Mod4+Shift+Return"
        //      "<Super> 2"         -> "Mod4+2"
        //
        // IMPORTANT: in the JSON the Super key is stored as <U+F17A> — a
        // 3-byte FontAwesome glyph (0xEF 0x85 0xBA), not the literal two-char
        // "<>".  So index_of(">") returns 4 for that token, not 1.
        // We detect the Super token by checking whether the first byte of tok
        // is non-ASCII (> 0x7F), which uniquely identifies the icon glyph.
        var mods = new StringBuilder ();
        string remaining = raw_keybinding;

        // Consume leading modifier tokens of the form <...>.
        while (remaining.has_prefix ("<")) {
            int close = remaining.index_of (">");
            if (close < 0) break;  // malformed — no closing '>'

            string tok = remaining.slice (1, close);

            if      (tok == "Shift")  mods.append ("Shift+");
            else if (tok == "Alt")    mods.append ("Mod1+");
            else if (tok == "Ctrl")   mods.append ("Control+");
            else if (tok == "CAPS")   mods.append ("Lock+");
            else if (tok.length == 0 || (uint8) tok[0] > 127)
                                      mods.append ("Mod4+");  // bare <> or Super icon
            // truly unknown ASCII modifier tokens are silently ignored

            remaining = remaining.slice (close + 1, remaining.length);
        }

        // Skip the single space that separates modifiers from the key name.
        if (remaining.has_prefix (" "))
            remaining = remaining.slice (1, remaining.length);

        if (remaining.length == 0) return "";

        // Normalise key name to sway conventions.
        string key = remaining;
        if      (key == "Enter") key = "Return";
        else if (key == "↑")     key = "Up";
        else if (key == "↓")     key = "Down";
        else if (key == "←")     key = "Left";
        else if (key == "→")     key = "Right";

        return mods.str + key;
    }
  }
}
