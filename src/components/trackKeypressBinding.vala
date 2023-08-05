using Gtk;
using Gee;

namespace regolith_onboarding{
  public class KeybindingsHandler {
    public HashTable<string,uint> nonModifiers; 
    public HashTable<string,int> modifierMasks;
    public KeybindingsHandler() {
      nonModifiers = new HashTable<string, uint>(str_hash, str_equal);
      modifierMasks = new HashTable<string, int>(str_hash, str_equal);
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
    }

    public bool match(Gdk.EventKey key, uint modifierMask, uint nonModifier){
     stdout.printf("\n keyval : %u nonmodifier :  %u \n", key.keyval,nonModifier); 
     if ((key.state & modifierMask) == modifierMask && key.keyval == nonModifier) {
       stdout.printf("matched!"); 
       return true;
     } 
     return false;
    }
  }
}
