using Gtk;
using Gee;

namespace regolith_onboarding{
  public class KeybindingsHandler {
    public HashTable<string,uint> nonModifiers; 
    public HashTable<string,int> modifierMasks;
    public HashTable<string,string> remontoireSymToKey;
    public KeybindingsHandler() {
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
      
      modifierMasks.insert ("", Gdk.ModifierType.SUPER_MASK);
      modifierMasks.insert ("Shift",Gdk.ModifierType.SHIFT_MASK);
      modifierMasks.insert ("Alt", Gdk.ModifierType.MOD1_MASK);
      modifierMasks.insert ("Ctrl",Gdk.ModifierType.CONTROL_MASK);
      modifierMasks.insert ("CAPS",Gdk.ModifierType.LOCK_MASK);

      remontoireSymToKey.insert ("", "Super_L");
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
