/*
 * src/editorDocument.cw - One open editor tab (view, path, disk text).
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
 * One notebook tab: a source view, its path, and the text last read
 * from disk. The editor saves, retitles, and closes this document.
 */
class EditorDocument {
    public:
    /*
     * _self
     *
     * Purpose: Return this document so GTK callbacks can use it.
     *
     * Parameters:
     *   none.
     *
     * Returns: this instance for GTK callbacks.
     */

    EditorDocument _self()
    void<EditorDocument> closeAction
    GtkSource.View view
    Gtk.ScrolledWindow scroller
    String path
    String baseName
    list shortcuts
    bool shortcutConflict
    int64 shortcutRevision
    String automaticSaveError
    String lastTitle
    String diskText
    int64 lspVersion

    /*
     * EditorDocument
     *
     * Purpose: Create a monospace source view of contents, marked saved,
     * and wrap it in the tab scroller. Language follows filePath.
     *
     * Parameters:
     *   filePath — file path, or "" for an untitled buffer.
     *   contents — initial text, also stored as diskText.
     *
     * Returns: the new EditorDocument.
     */

    EditorDocument(String filePath, String contents) {
        path = filePath
        baseName = ""
        if (!path.equals("")) {
            baseName = System.FileSystem().basename(path)
        }
        shortcuts = []
        shortcutConflict = false
        automaticSaveError = ""
        lastTitle = ""
        diskText = contents
        lspVersion = 1
        view = GtkSource.View()
        view.setMonospace(true)
        view.setEmojiMenu(false)
        view.setLanguage(GtkSource.Content().languageFor(filePath))
        view.setText(contents)
        view.markSaved()
        scroller = Gtk.ScrolledWindow()
        // Automatic policy: GTK #6057 (adjustment updates during TextView
        // snapshot) is worse with POLICY_ALWAYS; cwhip filters that warning.
        scroller.setHExpand(true)
        scroller.setVExpand(true)
        view.widget().setHExpand(true)
        view.widget().setVExpand(true)
        scroller.setChild(view.widget())
    }

    /*
     * updatePath
     *
     * Purpose: Replace path and set baseName from its file name. An empty
     * path clears the base name.
     *
     * Parameters:
     *   newPath — replacement path, or "" when untitled.
     *
     * Returns: nothing.
     */

    void updatePath(String newPath) {
        path = newPath
        if (!path.equals("")) {
            baseName = System.FileSystem().basename(path)
        }
        else {
            baseName = ""
        }
    }

    /*
     * tabTitle
     *
     * Purpose: Update the notebook page title when the document tab title
     * changed.
     *
     * Parameters:
     *   none.
     *
     * Returns: String.
     */

    String tabTitle() {
        String title = "Untitled"
        if (!baseName.equals("")) {
            title = baseName
        }
        if (view.modified()) {
            title.append("*")
        }
        return(title)
    }
    /*
     * stripTrailingSpaces
     *
     * Purpose: Remove trailing spaces and tabs from the source view.
     *
     * Parameters:
     *   none.
     *
     * Returns: true when any trailing space or tab was removed.
     */

    bool stripTrailingSpaces() {
        return(view.stripTrailingSpaces())
    }
    /*
     * close
     *
     * Purpose: Call closeAction, passing this document.
     *
     * Parameters:
     *   none.
     *
     * Returns: nothing.
     */

    void close() {
        closeAction(_self())
    }
}
/*
 * EditorDocument._self
 *
 * Purpose: Return this document for GTK callbacks that need a receiver.
 *
 * Parameters:
 *   none.
 *
 * Returns: this EditorDocument.
 */

EditorDocument EditorDocument._self() from "cwhip_gtk_self"
