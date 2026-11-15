/*
 * src/workspaceFile.cw - One open-tab path plus caret for workspace
 * persistence.
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
 * One open tab recorded in the workspace: its path and the caret
 * line and column used to restore the session.
 */
class WorkspaceFile {
    public:
    String path
    int64 line
    int64 column
    /*
     * WorkspaceFile
     *
     * Purpose: Store one open tab's path and caret position.
     *
     * Parameters:
     *   file — path remembered for the tab.
     *   row — caret line.
     *   col — caret column.
     *
     * Returns: the new WorkspaceFile.
     */

    WorkspaceFile(String file, int64 row, int64 col) {
        path = file
        line = row
        column = col
    }
}

// Project metadata paths are always derived from the canonical root, never
// from persisted contents.
