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
     */
    public class KeySynthesizer : GLib.Object {

        private KeybindingsHandler keys = new KeybindingsHandler ();
        private configManager cfg = new configManager ();

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

            var parts = cfg.format_spec (key_id).split (" ");
            for (int i = 0; i < parts.length - 1; i++) {
                var k = keys.remontoireSymToKey[parts[i]];
                command += (use_ydotool ? to_ydotool_key (k) : k) + "+";
            }

            var last = parts[parts.length - 1];
            var raw = (keys.remontoireSymToKey.get (last) != (string) null)
                      ? keys.remontoireSymToKey[last]
                      : last;
            command += use_ydotool ? to_ydotool_key (raw) : raw;

            return command;
        }

        // ydotool speaks Linux input-event names (KEY_ENTER) rather than X11
        // keysym names (Return).
        private string to_ydotool_key (string xkey) {
            switch (xkey) {
                case "Return":    return "KEY_ENTER";
                case "Up":        return "KEY_UP";
                case "Down":      return "KEY_DOWN";
                case "Left":      return "KEY_LEFT";
                case "Right":     return "KEY_RIGHT";
                case "Caps_Lock": return "KEY_CAPSLOCK";
                case "Shift_L":   return "KEY_LEFTSHIFT";
                case "Alt_L":     return "KEY_LEFTALT";
                case "Control_L": return "KEY_LEFTCTRL";
                case "Super_L":   return "KEY_LEFTMETA";
                default:          return xkey;
            }
        }
    }
}
