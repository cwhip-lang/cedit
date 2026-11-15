/*
 * src/recentEntry.cw - Recent menu row that reopens a remembered path.
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
 * A recent-menu row bound to one path. Choosing the row asks the
 * editor to open that path again.
 */
class RecentEntry {
    public:
    RecentEntry _self()
    Cedit editor
    String path

    /*
     * RecentEntry
     *
     * Purpose: Remember the editor and the path this menu row reopens.
     *
     * Parameters:
     *   owner — editor that opens the path.
     *   filePath — path to open when the row is chosen.
     *
     * Returns: the new RecentEntry.
     */

    RecentEntry(Cedit owner, String filePath) {
        editor = owner
        path = filePath
    }

    /*
     * choose
     *
     * Purpose: Ask the editor to open this row's remembered path.
     *
     * Parameters:
     *   none.
     *
     * Returns: nothing.
     */

    void choose() {
        editor.openRecentPath(path)
    }
}
/*
 * RecentEntry._self
 *
 * Purpose: Return this row for GTK callbacks that need a receiver.
 *
 * Parameters:
 *   none.
 *
 * Returns: this RecentEntry.
 */

RecentEntry RecentEntry._self() from "cwhip_gtk_self"
