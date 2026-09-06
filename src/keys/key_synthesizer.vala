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
     * Builds a shell command that replays a keybinding through an input-synthesis
     * tool. This is the last-resort way to make a step's action actually happen:
     * we re-send the keys and let the window manager act on them as usual.
     *
     * Lives beside the other key tables rather than inside the dispatchers that
     * use it, even though it is the dispatchers' fallback: --check-workflows
     * prints the command it would build for every step, which is the only way an
     * author finds out that a key_id translates to something ydotool will refuse.
     * A translator nobody can inspect offline is a translator that fails
     * silently at practice time.
     */
    public class KeySynthesizer : GLib.Object {

        private KeyTables keys = new KeyTables ();
        private KeySpec  spec = new KeySpec ();

        /** Command that replays key_id, e.g. "<><Shift> Enter". */
        public string command_for (string key_id) {
            bool use_ydotool = false;
            string command;

            if (Desktop.get_default ().is_wayland) {
                // xdotool cannot inject into a Wayland compositor; ydotool goes
                // through /dev/uinput and can, when its daemon is running.
                use_ydotool = GLib.Environment.find_program_in_path ("ydotool") != null;
                command = use_ydotool ? "ydotool key "
                                      : "xdotool sleep 0.5 key --clearmodifiers ";
            } else {
                command = "xdotool sleep 0.5 key --clearmodifiers ";
            }

            var parts = spec.format_spec (key_id).split (" ");
            for (int i = 0; i < parts.length - 1; i++) {
                command += translate (parts[i], use_ydotool) + "+";
            }
            command += translate (parts[parts.length - 1], use_ydotool);

            return command;
        }

        // An unrecognised token passes through unchanged rather than becoming
        // null, which previously dropped the modifier from the command entirely.
        private string translate (string token, bool use_ydotool) {
            var mapped = keys.remontoireSymToKey.get (token);
            // Fall through to the keysym table so punctuation and Space reach
            // ydotool under names it recognises.
            var xkey = (mapped != null) ? mapped : spec.to_keysym (token);
            return use_ydotool ? to_ydotool_key (xkey) : xkey;
        }

        /**
         * Converts an X11 keysym name to the Linux input-event name ydotool wants:
         * "Return" is KEY_ENTER, "v" is KEY_V, "space" is KEY_SPACE.
         *
         * This path only runs when the real window-manager binding could not be
         * resolved, but it has to produce something valid when it does — an
         * unrecognised name makes ydotool fail silently, which looks exactly like
         * the step doing nothing.
         */
        private string to_ydotool_key (string xkey) {
            switch (xkey) {
                case "Return":       return "KEY_ENTER";
                case "Up":           return "KEY_UP";
                case "Down":         return "KEY_DOWN";
                case "Left":         return "KEY_LEFT";
                case "Right":        return "KEY_RIGHT";
                case "Tab":          return "KEY_TAB";
                case "Escape":       return "KEY_ESC";
                case "space":        return "KEY_SPACE";
                case "BackSpace":    return "KEY_BACKSPACE";
                case "Print":        return "KEY_SYSRQ";
                case "Caps_Lock":    return "KEY_CAPSLOCK";
                case "Shift_L":      return "KEY_LEFTSHIFT";
                case "Alt_L":        return "KEY_LEFTALT";
                case "Control_L":    return "KEY_LEFTCTRL";
                case "Super_L":      return "KEY_LEFTMETA";
                // Punctuation reaches ydotool as the physical key; any Shift the
                // binding needs is already part of the combination.
                case "question":
                case "slash":        return "KEY_SLASH";
                case "exclam":       return "KEY_1";
                case "plus":
                case "equal":        return "KEY_EQUAL";
                case "minus":        return "KEY_MINUS";
                case "period":       return "KEY_DOT";
                case "comma":        return "KEY_COMMA";
                case "backslash":    return "KEY_BACKSLASH";
                case "semicolon":    return "KEY_SEMICOLON";
                case "apostrophe":   return "KEY_APOSTROPHE";
                case "grave":        return "KEY_GRAVE";
                case "bracketleft":  return "KEY_LEFTBRACE";
                case "bracketright": return "KEY_RIGHTBRACE";
                default:             break;
            }

            // Single letters and digits map straight onto KEY_A .. KEY_Z, KEY_0 .. KEY_9.
            if (xkey.length == 1) {
                var c = xkey[0];
                if (c.isalpha ()) return "KEY_" + xkey.up ();
                if (c.isdigit ()) return "KEY_" + xkey;
            }

            warning ("no ydotool name for keysym '%s'; passing through", xkey);
            return xkey;
        }
    }
}
