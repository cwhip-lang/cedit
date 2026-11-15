/*
 * src/projectNode.cw - One tree row that may scan a directory.
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
 * A project-tree row that can scan one directory. The explorer
 * creates it when a folder expands and fills children from the scan.
 */
class ProjectNode {
    public:
    ProjectNode _self()
    ProjectExplorer explorer
    Gtk.DirectoryScan scan
    int64 id
    int64 generation
    int64 kind
    String path
    bool started
    bool populated
    bool complete
    String error

    /*
     * ProjectNode
     *
     * Purpose: Record the row, path, kind, and the explorer generation.
     * Kind 1 is a folder, which is the only kind load() scans.
     *
     * Parameters:
     *   owner — explorer that owns the row.
     *   row — tree row id.
     *   filePath — filesystem path shown on the row.
     *   entryKind — tree kind; 1 means a directory.
     *
     * Returns: the new ProjectNode.
     */

    ProjectNode(
            ProjectExplorer owner,
            int64 row,
            String filePath,
            int64 entryKind) {
        explorer = owner
        path = filePath
        kind = entryKind
        generation = owner.generation
        id = row
        error = ""
    }

    /*
     * load
     *
     * Purpose: If this is an unscanned folder, show Loading and start a
     * directory scan.
     *
     * Parameters:
     *   none.
     *
     * Returns: nothing.
     */

    void load() {
        if (kind != 1 || started) {
            return
        }
        started = true
        explorer.addMessage(id, "Loading...", "content-loading-symbolic")
        scan = Gtk.DirectoryScan(explorer.tree, path, explorer.hidden.active(),
                explorer.rootPath,
            explorer.excludes, _self().received)
    }

    /*
     * received
     *
     * Purpose: Ignore a stale generation or a disposed tree. Otherwise
     * append children, or on -1 show an error, empty folder, or restore.
     *
     * Parameters:
     *   count — entries in this batch, or -1 when the scan finished.
     *   message — error text used when count is -1.
     *
     * Returns: nothing.
     */

    void received(int64 count, String message) {
        if (generation != explorer.generation || explorer.tree.disposed()) {
            return
        }
        if (!populated) {
            populated = true
            explorer.tree.clear(id)
        }

        if (count == -1) {
            complete = true
            scan = null
            error = message
            explorer.showExternal()

            if (!error.equals("")) {
                explorer.addMessage(id, format(
                        "Could not read directory: {}",
                        error), "dialog-error-symbolic")
            }
            else {
                if (explorer.tree.childCount(id) == 0) {
                    explorer.addMessage(id, "(Empty folder)", "folder-symbolic")
                }
                explorer.restoreChildren(path)
            }

            return
        }

        scan.append(
                explorer.tree,
                id,
                explorer.nextId + 1,
                count,
                explorer.icons)
        explorer.nextId = explorer.nextId + count
        explorer.showExternal()
    }
}
/*
 * ProjectNode._self
 *
 * Purpose: Return this row for GTK callbacks that need a receiver.
 *
 * Parameters:
 *   none.
 *
 * Returns: this ProjectNode.
 */

ProjectNode ProjectNode._self() from "cwhip_gtk_self"
