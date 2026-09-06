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
   * Translation between the three ways a keybinding is written down here.
   *
   * Workflow JSON carries a remontoire spec ("<><Shift> Enter"); a window
   * manager wants a bindsym spec ("Mod4+Shift+Return"); the user wants to read
   * something with the brackets stripped out. None of that is desktop-specific
   * — it is string and table work that every platform under src/platforms/ does
   * identically — so it lives here rather than being owned by any one of them.
   *
   * Pure functions with no session state, deliberately: --check-workflows calls
   * these with no display connection at all.
   */
  public class KeySpec {

    public string format_spec (string raw_keybinding) {
        // TODO: this won't work for keybindings with < > characters
        return raw_keybinding
                .replace ("<", "")
                .replace (">", " ")
                .replace ("  ", " ");
    }
    public string format_spec_display (string raw_keybinding) {
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

        return mods.str + to_keysym (remaining);
    }

    /**
     * Maps a remontoire key name to the X11 keysym name a window manager will
     * accept in a bindsym.
     *
     * These are not interchangeable: sway rejects "bindsym Mod4+Shift+? nop"
     * outright with "Unknown key or button", which invalidates the whole config
     * file, and it silently canonicalises "Space" to "space" so a literal
     * comparison against the binding event would never match.
     */
    public string to_keysym (string key) {
        switch (key) {
            case "Enter":     return "Return";
            case "↑":       return "Up";
            case "↓":       return "Down";
            case "←":       return "Left";
            case "→":       return "Right";
            case "Space":
            case "space":     return "space";
            case "?":         return "question";
            case "!":         return "exclam";
            case "+":         return "plus";
            case "-":         return "minus";
            case "=":         return "equal";
            case ".":         return "period";
            case ",":         return "comma";
            case "/":         return "slash";
            case "\\":        return "backslash";
            case ";":         return "semicolon";
            case "'":         return "apostrophe";
            case "`":         return "grave";
            case "[":         return "bracketleft";
            case "]":         return "bracketright";
            case "Backspace": return "BackSpace";
            case "Prtscr":
            case "PrtScr":    return "Print";
            default:          return key;
        }
    }
  }
}
