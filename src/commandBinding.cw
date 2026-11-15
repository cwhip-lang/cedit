/*
 * src/commandBinding.cw - Named editor command plus keyboard trigger.
 *
 * Created: 2026-10-29
 * Author: Auto
 *
 * Changelog:
 *   2026-10-29  Initial file.
 *   2026-11-13  CODING headers and method comments.
 *   2026-11-14  Public members for private-by-default cwhip.
 *   2026-11-15  Apply the revised coding standard.
 */

/*
 * A named editor command and the keyboard trigger that runs it.
 * Preferences edit the trigger; documents bind a non-empty valid one.
 */
class CommandBinding {
    public:
    String id
    String name
    String defaultTrigger
    String trigger
    String normalized
    bool valid
    void<> action
    /*
     * CommandBinding
     *
     * Purpose: Store the command id, label, and default shortcut, then
     * apply that shortcut as the current trigger.
     *
     * Parameters:
     *   command — command id, kept as id.
     *   label — display name, kept as name.
     *   shortcut — built-in trigger, also applied now.
     *
     * Returns: the new CommandBinding.
     */

    CommandBinding(String command, String label, String shortcut) {
        id = command
        name = label
        defaultTrigger = shortcut
        setTrigger(shortcut)
    }
    /*
     * setTrigger
     *
     * Purpose: Store shortcut and normalize a non-empty one with
     * Gtk.Keyboard. Empty, or a normalization that yields text, is valid.
     *
     * Parameters:
     *   shortcut — trigger text; empty means no shortcut.
     *
     * Returns: nothing.
     */

    void setTrigger(String shortcut) {
        trigger = shortcut
        normalized = ""
        if (!shortcut.equals("")) {
            normalized = Gtk.Keyboard().normalize(shortcut)
        }
        valid = shortcut.equals("") || normalized.length > 0
    }
}
