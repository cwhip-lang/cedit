/*
 * src/ceditApplyConfigure.cw - Configure Apply, About, and open/save helpers.
 *
 * Created: 2026-10-29
 * Author: Auto
 *
 * Changelog:
 *   2026-10-29  Initial file.
 *   2026-11-13  CODING headers and method comments.
 *   2026-11-15  Apply the revised coding standard.
 */

/*
 * Apply Configure Project values onto the active project.
 *
 * Purpose: Validate the name, exclusions, and active overrides, then store
 * them and write the project configuration. Refresh open documents
 * when the values are accepted.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.applyConfigure() {
    CwhipProject current = activeProject
    if (current == null || commandsBlocked()) {
        return
    }

    if (!current.writable) {
        configureMessage.setText(diagnostic("CEDIT2002", format(
                "{}: repair and reopen the project before changing it: {}",
                current.configPath,
                current.errors)))
        return
    }

    String name = configureName.text().trim()
    String problem = current.nameError(name)
    list patterns = []
    list parts = configureExcludes.text().split(",")
    int64 index = 0
    while (index < parts.length) {
        String pattern = (parts[index] as String).trim()
        if (!pattern.equals("")) {
            String patternProblem = current.excludeError(pattern)
            if (problem.equals("")) {
                problem = patternProblem
            }
            patterns.append(pattern)
        }
        index = index + 1
    }

    OverrideRow fontRow = overrideRow("font_family")
    OverrideRow sizeRow = overrideRow("font_size")
    OverrideRow tabsRow = overrideRow("tab_width")
    int64 size = preferenceNumber(sizeRow.entry.text(), 6, 72)
    int64 tabs = preferenceNumber(tabsRow.entry.text(), 1, 16)
    if (problem.equals("") && fontRow.override.active()) {
        problem = settings.fontError(fontRow.entry.text())
    }
    if (problem.equals("") && sizeRow.override.active() && size < 0) {
        problem = "Font size must be an integer from 6 to 72"
    }
    if (problem.equals("") && tabsRow.override.active() && tabs < 0) {
        problem = "Tab width must be an integer from 1 to 16"
    }
    if (!problem.equals("")) {
        configureMessage.setText(problem)
        return
    }
    String oldExcludes = current.excludeLines()
    current.name = name
    current.excludes = patterns
    current.hasFont = fontRow.override.active()
    if (current.hasFont) {
        current.fontFamily = fontRow.entry.text()
    }
    current.hasSize = sizeRow.override.active()
    if (current.hasSize) {
        current.fontSize = size
    }
    current.hasTabs = tabsRow.override.active()
    if (current.hasTabs) {
        current.tabWidth = tabs
    }
    OverrideRow row = overrideRow("insert_spaces")
    current.hasSpaces = row.override.active()
    current.insertSpaces = row.value.active()
    row = overrideRow("line_numbers")
    current.hasNumbers = row.override.active()
    current.lineNumbers = row.value.active()
    row = overrideRow("wrap")
    current.hasWrap = row.override.active()
    current.wrap = row.value.active()
    row = overrideRow("highlight_current_line")
    current.hasHighlight = row.override.active()
    current.highlightLine = row.value.active()
    reapplyDocumentSettings()
    refreshProjectNote()
    project.title.setText(current.name)
    if (!oldExcludes.equals(current.excludeLines())) {
        project.setProject(current.root, current.name, current.excludeLines(),
                project.expandedPaths())
    }
    configureMessage.setText("Saving project configuration...")
    writeProject(current, true, false, "configure")
}

/*
 * Hide the Configure Project window without destroying it.
 *
 * Purpose: Call setVisible(false) when the window still exists.
 *
 * Parameters:
 *   none.
 *
 * Returns: true (consume the close request).
 */

bool Cedit.hideConfigure() {
    if (configureWindow != null && !configureWindow.disposed()) {
        configureWindow.setVisible(false)
    }
    return(true)
}

/*
 * Close the Configure Project window.
 *
 * Purpose: Hide the window by calling hideConfigure.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.closeConfigure() {
    hideConfigure()
}

/*
 * Show the About cedit window.
 *
 * Purpose: Build the About window on first use and present it. Do nothing
 * while a file dialog is open.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.showAbout() {
    if (fileDialog != null) {
        return
    }

    if (aboutWindow == null || aboutWindow.disposed()) {
        aboutWindow = Gtk.TransientWindow("About cedit")
        aboutWindow.setTransientFor(window)
        aboutWindow.setDefaultSize(480, 300)
        Gtk.Box root = Gtk.Box(Gtk.Box.VERTICAL, 8)
        root.append(Gtk.Label("cedit"))
        root.append(Gtk.Label(format("Version {}", version())))
        root.append(Gtk.Label(
                "A GTK editor for Cwhip, written in Cwhip\nwith GtkSourceView syntax highlighting, a project explorer,\nand per-project configuration."))
        root.append(Gtk.Label(
                "License: no license file is included in the repository."))
        root.append(Gtk.Label("Website: https://cwhip.org"))
        root.append(Gtk.Label(
                "Project repository: https://github.com/cwhip-lang/cwhip"))
        Gtk.Button close = Gtk.Button("Close")
        close.onClicked(_self().closeAbout)
        root.append(close)
        aboutWindow.setChild(root)
        aboutWindow.onCloseRequest(_self().hideAbout)
    }

    aboutWindow.present()
}

/*
 * Hide the About window without destroying it.
 *
 * Purpose: Call setVisible(false) when the window still exists.
 *
 * Parameters:
 *   none.
 *
 * Returns: true (consume the close request).
 */

bool Cedit.hideAbout() {
    if (aboutWindow != null && !aboutWindow.disposed()) {
        aboutWindow.setVisible(false)
    }
    return(true)
}

/*
 * Close the About window.
 *
 * Purpose: Hide the window by calling hideAbout.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.closeAbout() {
    hideAbout()
}

/*
 * Open a new untitled document tab.
 *
 * Purpose: Append an empty document, add its notebook page, and activate
 * it. Do nothing while commands are blocked.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.newDocument() {
    if (commandsBlocked()) {
        return
    }
    EditorDocument document = EditorDocument("", "")
    documents.append(document)
    document.closeAction = _self().closeDocument
    notebook.appendClosablePage(
            document.scroller,
            document.tabTitle(),
            document.close)
    configureShortcuts(document)
    activateDocument(document)
}

/*
 * Open a local text file as a document.
 *
 * Purpose: Reuse an already-open tab or append a new document. Return
 * null for empty, --test, remote, missing, binary, or unreadable paths.
 *
 * Parameters:
 *   requestedPath — local filesystem path to open.
 *
 * Returns: the open document, or null when the file cannot be opened.
 */

EditorDocument Cedit.openDocument(String requestedPath) {
    if (requestedPath.equals("") || requestedPath.equals("--test")) {
        return(null)
    }
    if (requestedPath.contains("://")) {
        reportOpenFailure(format(
                "Open failed: {}: only local filesystem paths are supported",
                                     requestedPath), false)
        return(null)
    }
    String absolutePath = System.FileSystem().absolutePath(requestedPath)
    if (absolutePath.equals("")) {
        reportOpenFailure(format("Open failed: {}: {}", requestedPath,
                                     System.System().lastError()), false)
        return(null)
    }
    int64 index = 0
    while (index < documents.length) {
        EditorDocument existing = documents[index] as EditorDocument
        if (existing.path.equals(absolutePath)) {
            rememberRecent(absolutePath)
            return(existing)
        }
        index = index + 1
    }
    if (!System.FileSystem().isFile(absolutePath)) {
        reportOpenFailure(format(
                "Open failed: {} is not a regular file",
                requestedPath), false)
        return(null)
    }
    System.File input = null
    try {
        input = System.File(absolutePath, "r")
    }
    except(Exception) {
        reportOpenFailure(format("Open failed: {}: {}", requestedPath,
                                     System.System().lastError()), false)
        return(null)
    }
    String text = ""
    String readError = ""
    bool binary = false
    try {
        text = input.readAll()
        readError = System.System().lastError()
    }
    except(Exception) as error {
        readError = error.message
        binary = readError.contains("UTF-8")
    }
    input.close()
    if (binary || (readError.equals("") && !GtkSource.Content().isText(text))) {
        reportOpenFailure(format(
                "Open failed: {} is not a text file (binary or not UTF-8)",
                                     absolutePath), true)
        return(null)
    }

    if (!readError.equals("")) {
        reportOpenFailure(
                format(
                "Open failed: {}: {}",
                absolutePath,
                readError),
                false)
        return(null)
    }

    EditorDocument document = EditorDocument(absolutePath, text)
    documents.append(document)
    document.closeAction = _self().closeDocument
    notebook.appendClosablePage(
            document.scroller,
            document.tabTitle(),
            document.close)
    configureShortcuts(document)
    rememberRecent(absolutePath)
    project.noteFile(absolutePath)
    if (client != null && client.ready) {
        client.sendOpen(document)
    }
    return(document)
}

/*
 * Report a failed file open.
 *
 * Purpose: Put a CEDIT1001 diagnostic on the status line. Collect it when
 * failures are being gathered, or show an alert when dialog is true.
 *
 * Parameters:
 *   message — failure text to report.
 *   dialog — true to show an alert outside failure collection.
 *
 * Returns: nothing.
 */

void Cedit.reportOpenFailure(String message, bool dialog) {
    String recovery = "Choose a local, readable text file and retry."
    String reported = diagnostic("CEDIT1001", format("{}; {}", message,
            recovery))
    status.setText(reported)
    if (collectingFailures) {
        openFailures.append(reported)
    }
    else {
        if (dialog) {
            Gtk.AlertDialog().show(window, "Could not open file", reported)
        }
    }
}

/*
 * Switch the notebook to one document.
 *
 * Purpose: Select the document's page, update status, and focus its view.
 * Capture search scope when the search dialog is open on a selection.
 *
 * Parameters:
 *   document — document to show.
 *
 * Returns: nothing.
 */

void Cedit.activateDocument(EditorDocument document) {
    if (document == null) {
        return
    }

    int64 index = 0
    while (index < documents.length) {
        if ((documents[index] as EditorDocument) == document) {
            notebook.setCurrentPage(index)
            updateStatus()
            document.view.focus()
                // pageChanged defers capture; tests and Ctrl+Tab need it now.
            if (searchDialogOpen && document.view.hasSelection()) {
                document.view.captureSearchScope()
            }
            return
        }
        index = index + 1
    }

    status.setText("Document is not open")
}

/*
 * Open a path and show its tab.
 *
 * Purpose: Open requestedPath and activate the document when that succeeds.
 *
 * Parameters:
 *   requestedPath — local filesystem path to open.
 *
 * Returns: nothing.
 */

void Cedit.openFile(String requestedPath) {
    EditorDocument document = openDocument(requestedPath)
    if (document != null) {
        activateDocument(document)
    }
}

/*
 * Return the document for the current notebook page.
 *
 * Purpose: Map the current notebook page onto the document list.
 *
 * Parameters:
 *   none.
 *
 * Returns: that document, or null when no page is selected.
 */

EditorDocument Cedit.currentDocument() {
    int64 page = notebook.currentPage()
    if (page < 0 || page >= documents.length) {
        return(null)
    }
    return(documents[page] as EditorDocument)
}

/*
 * Save the current document.
 *
 * Purpose: Write the current tab to its path, or open Save As when the tab
 * is untitled. Do nothing while commands are blocked.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.saveCurrent() {
    if (commandsBlocked()) {
        return
    }
    EditorDocument document = currentDocument()
    if (document == null) {
        status.setText("No document to save")
        return
    }
    String destination = document.path
    if (destination.equals("")) {
        chooseSave(document, false)
        return
    }
    writeDocument(document, destination)
}

/*
 * Save every modified document that already has a path.
 *
 * Purpose: Write those tabs and count untitled ones as skipped. Do not
 * report success when any write fails.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.saveAll() {
    if (commandsBlocked()) {
        return
    }

    int64 saved = 0
    int64 skipped = 0
    int64 failed = 0
    int64 i = 0
    while (i < documents.length) {

        EditorDocument doc = documents[i] as EditorDocument
        if (doc.view.modified()) {

            if (doc.path.equals("")) {
                skipped = skipped + 1
            }
                else {
                if (writeDocument(doc, doc.path)) {
                    saved = saved + 1
                }
                else {
                    failed = failed + 1
                }
            }

        }

        i = i + 1
    }

    if (failed > 0) {
        return
    }

    if (skipped > 0) {
        status.setText(format(
                "Saved {} file(s); {} untitled document(s) not saved",
                saved,
                skipped))
    }
        else {
        status.setText(format(
                "Saved {} file(s){}",
                saved,
                automaticSaveErrors()))
    }

}

/*
 * Strip trailing spaces on the current document.
 *
 * Purpose: Strip the current tab and report whether any spaces were
 * removed. Do nothing while commands are blocked or no document is open.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.stripTrailingSpacesCurrent() {
    if (commandsBlocked()) {
        return
    }
    EditorDocument document = currentDocument()
    if (document == null) {
        return
    }
    if (document.stripTrailingSpaces()) {
        status.setText("Stripped trailing spaces")
    }
        else {
        status.setText("No trailing spaces")
    }
}

/*
 * Save the current document under a chosen path.
 *
 * Purpose: Open the save dialog for the current tab. Do nothing while
 * commands are blocked or no document is open.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.saveAsCurrent() {
    if (commandsBlocked()) {
        return
    }
    EditorDocument document = currentDocument()
    if (document == null) {
        status.setText("No document to save")
        return
    }
    chooseSave(document, false)
}

