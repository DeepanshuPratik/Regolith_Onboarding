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

  // Keyvals the observers compare a GDK key event against. Plain numbers rather
  // than Gdk.Key constants because the tables below are indexed by the same
  // remontoire names the workflow JSON uses, not by GDK symbols.
  public const int KEY_CODE_ESCAPE = 65307;
  public const int KEY_CODE_TAB    = 65289;
  public const int KEY_CODE_UP     = 65362;
  public const int KEY_CODE_DOWN   = 65364;
  public const int KEY_CODE_LEFT   = 65361;
  public const int KEY_CODE_RIGHT  = 65363;
  public const int KEY_CODE_ENTER  = 65293;

  /**
   * The lookup tables that turn a remontoire modifier or key name into a GDK
   * mask, a keyval, or an X11 keysym name.
   *
   * Shared rather than per-platform for the same reason as KeySpec: the tables
   * describe the workflow-JSON vocabulary, which is one vocabulary regardless
   * of which desktop is reading it. A platform that needed a different mapping
   * would be describing a different input language, not a different desktop.
   */
  public class KeyTables {

    // The FontAwesome Linux glyph Regolith uses to mean the Super key.
    public const string SUPER_GLYPH = "";

    public HashTable<string,uint> nonModifiers; 
    public HashTable<string,int> modifierMasks;
    public HashTable<string,string> remontoireSymToKey;
    public KeyTables () {
      nonModifiers = new HashTable<string, uint>(str_hash, str_equal);
      modifierMasks = new HashTable<string, int>(str_hash, str_equal);
      remontoireSymToKey = new HashTable<string,string> (str_hash, str_equal);
      
      nonModifiers.insert ("Enter",KEY_CODE_ENTER);
      nonModifiers.insert ("↑", KEY_CODE_UP);
      nonModifiers.insert ("↓", KEY_CODE_DOWN);
      nonModifiers.insert ("←", KEY_CODE_LEFT);
      nonModifiers.insert ("→", KEY_CODE_RIGHT);
      nonModifiers.insert ("Tab",KEY_CODE_TAB);
      nonModifiers.insert ("Escape", KEY_CODE_ESCAPE);
      
      // Super appears two ways in workflow files: as the FontAwesome glyph
      // U+F17A that Regolith's own configs use, and as a plain empty "<>",
      // which is what an author writing JSON by hand will naturally produce.
      // Both must resolve, or the modifier is silently dropped.
      modifierMasks.insert (SUPER_GLYPH, Gdk.ModifierType.SUPER_MASK);
      modifierMasks.insert ("", Gdk.ModifierType.SUPER_MASK);
      modifierMasks.insert ("Shift",Gdk.ModifierType.SHIFT_MASK);
      modifierMasks.insert ("Alt", Gdk.ModifierType.MOD1_MASK);
      modifierMasks.insert ("Ctrl",Gdk.ModifierType.CONTROL_MASK);
      modifierMasks.insert ("CAPS",Gdk.ModifierType.LOCK_MASK);

      remontoireSymToKey.insert (SUPER_GLYPH, "Super_L");
      remontoireSymToKey.insert ("", "Super_L");
      remontoireSymToKey.insert ("Shift","Shift_L");
      remontoireSymToKey.insert ("Alt", "Alt_L");
      remontoireSymToKey.insert ("Ctrl","Control_L");
      remontoireSymToKey.insert ("CAPS","Caps_Lock");
      remontoireSymToKey.insert ("Enter","Return");
      remontoireSymToKey.insert ("↑","Up");
      remontoireSymToKey.insert ("↓","Down");
      remontoireSymToKey.insert ("←","Left");
      remontoireSymToKey.insert ("→","Right");
    }

    public bool match(Gdk.EventKey key, uint modifierMask, uint nonModifier, bool isOnNonModifierMap){
     // stdout.printf("\n keyState: %u keyState&modifierMask : %u keyval : %u nonmodifier :  %u \n",key.state, key.state & modifierMask, key.keyval,nonModifier); 

     if ((modifierMask & modifierMasks["Shift"]) == modifierMasks["Shift"] && !isOnNonModifierMap) {
       var upped = nonModifier.to_string("%c").up();
       nonModifier = upped[0];
       stdout.printf("\nshifted nonmod: %s\n", upped);
     }

     var isModifierMatch = (key.state & modifierMask) == modifierMask;
     var isNonModifierMatch = key.keyval == nonModifier; 

     if ( isModifierMatch && isNonModifierMatch) {
       return true;
     } 
     return false;
    }
  }
}
