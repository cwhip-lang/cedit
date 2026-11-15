/*
 * src/overrideRow.cw - Project-configure row for one setting override.
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
 * A Project Configure row for one editor setting. The override
 * checkbox replaces the preference with a check or a text value.
 */
class OverrideRow {
    public:
    /*
     * _self
     *
     * Purpose: Return this row so GTK callbacks can use it.
     *
     * Parameters:
     *   none.
     *
     * Returns: this instance for GTK callbacks.
     */

    OverrideRow _self()
    String key
    bool boolean
    Gtk.Box row
    Gtk.CheckButton override
    Gtk.Entry entry
    Gtk.CheckButton value

    /*
     * OverrideRow
     *
     * Purpose: Build an Override checkbox plus an Enabled check or a text
     * entry, and connect the checkbox to toggled.
     *
     * Parameters:
     *   settingKey — project setting key this row edits.
     *   label — setting name shown after Override.
     *   flag — true when the setting is a boolean checkbox.
     *
     * Returns: the new OverrideRow.
     */

    OverrideRow(String settingKey, String label, bool flag) {
        key = settingKey
        boolean = flag
        row = Gtk.Box(Gtk.Box.HORIZONTAL, 6)
        override = Gtk.CheckButton(format("Override {}", label))
        row.append(override)
        if (boolean) {
            value = Gtk.CheckButton("Enabled")
            row.append(value)
        }
        else {
            entry = Gtk.Entry("")
            entry.setHExpand(true)
            row.append(entry)
        }
        override.onToggled(_self().toggled)
    }

    /*
     * toggled
     *
     * Purpose: Make the entry or Enabled checkbox sensitive only when
     * active is true.
     *
     * Parameters:
     *   active — true when the override checkbox is checked.
     *
     * Returns: nothing.
     */

    void toggled(bool active) {
        if (boolean) {
            value.setSensitive(active)
        }
        else {
            entry.setSensitive(active)
        }
    }

    /*
     * show
     *
     * Purpose: Show the override flag and the text or boolean value, then
     * enable that control only when the override is on.
     *
     * Parameters:
     *   overridden — true when this setting overrides preferences.
     *   text — entry contents for a non-boolean setting.
     *   flag — checked state for a boolean setting.
     *
     * Returns: nothing.
     */

    void show(bool overridden, String text, bool flag) {
        override.setActive(overridden)
        if (boolean) {
            value.setActive(flag)
        }
        else {
            entry.setText(text)
        }
        toggled(overridden)
    }
}
/*
 * OverrideRow._self
 *
 * Purpose: Return this row for GTK callbacks that need a receiver.
 *
 * Parameters:
 *   none.
 *
 * Returns: this OverrideRow.
 */

OverrideRow OverrideRow._self() from "cwhip_gtk_self"
