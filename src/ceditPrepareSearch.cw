/*
 * src/ceditPrepareSearch.cw - Find/replace dialog, status, and window close.
 *
 * Created: 2026-10-29
 * Author: Auto
 *
 * Changelog:
 *   2026-10-29  Initial file.
 *   2026-11-13  CODING headers and method comments.
 *   2026-11-15  Apply the revised coding standard.
 *   2026-11-15  Enable Format Selection only when text is selected.
 */

/*
 * Cedit.prepareSearch
 *
 * Purpose: Save the search scope and copy a single-line selection into Find.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.prepareSearch() {
    EditorDocument document = currentDocument()
    if (document == null) {
        return
    }
    String selected = document.view.selectedText()
    document.view.captureSearchScope()
    if (!selected.equals("") && !selected.contains("\n")) {
        findEntry.setText(selected)
    }
}

/*
 * Cedit.showFind
 *
 * Purpose: When commands are allowed, open Find, hide replace, and focus
 * the find field.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.showFind() {
    if (!commandsBlocked()) {
        searchWindow.setTitle("Find")
        replaceRow.setVisible(false)
        prepareSearch()
        searchDialogOpen = true
        searchWindow.present()
        findEntry.focus()
    }
}

/*
 * Cedit.showReplace
 *
 * Purpose: When commands are allowed, open Find and Replace and focus
 * the replace field.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.showReplace() {
    if (!commandsBlocked()) {
        searchWindow.setTitle("Find and Replace")
        replaceRow.setVisible(true)
        prepareSearch()
        searchDialogOpen = true
        searchWindow.present()
        replaceEntry.focus()
    }
}

/*
 * Cedit.hideSearchDialog
 *
 * Purpose: Hide the search window and mark the dialog closed.
 *
 * Parameters:
 *   none.
 *
 * Returns: true to consume the close request.
 */

bool Cedit.hideSearchDialog() {
    searchDialogOpen = false
    searchWindow.setVisible(false)
    return(true)
}

/*
 * Cedit.closeSearchDialog
 *
 * Purpose: Mark the search dialog closed and dispose its window.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.closeSearchDialog() {
    searchDialogOpen = false
    if (searchWindow != null && !searchWindow.disposed()) {
        searchWindow.dispose()
    }
}

/*
 * Cedit.changed
 *
 * Purpose: After an edit, refresh the tab, schedule unsaved marks, notify
 * the language client, and update edit actions.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.changed() {
    if (window == null || window.disposed() || changingDocuments) {
        return
    }
    EditorDocument document = currentDocument()
    if (document != null) {
        refreshTab(document)
            // Defer mark rebuild so undo/redo snapshot is not racing gutter
            // updates.
        scheduleUnsavedMarks()
        if (client != null) {
            client.noteEdit()
        }
    }
    updateEditActions()
}

/*
 * Cedit.cursorMoved
 *
 * Purpose: Refresh the status line and Cut and Copy after the cursor moves.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.cursorMoved() {
    if (window == null || window.disposed() || changingDocuments) {
        return
    }
    updateStatusText()
    updateSelectionActions()
}

/*
 * Cedit.pageChanged
 *
 * Purpose: Count the notebook page change and defer the tab-switch work.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.pageChanged() {
    pageChanges = pageChanges + 1
    if (changingDocuments || window.disposed()) {
        return
    }
        // Defer tab-loss work so it does not run inside GtkNotebook's arrow
        // press handler (which can drop the matching release and stick the
        // scroll arrows until another tab is clicked).
    Gtk.Application().post(_self().pageChangedDeferred)
}

/*
 * Cedit.pageChangedDeferred
 *
 * Purpose: On a tab switch, save the previous document when configured,
 * refresh search scope and status, and check the file on disk.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.pageChangedDeferred() {
    if (changingDocuments || window.disposed()) {
        return
    }
    EditorDocument previous = focusedDocument
    focusedDocument = currentDocument()
    if (!changingDocuments && previous != focusedDocument
            && settings.saveOnTabLoss) {
        automaticSave(previous)
    }
    if (searchDialogOpen) {
        EditorDocument document = currentDocument()
        if (document != null && document.view.hasSelection()) {
            document.view.captureSearchScope()
        }
    }
    updateStatus()
    checkDiskChange()
}

/*
 * Cedit.automaticSave
 *
 * Purpose: Save a modified named document. A failed write is stored as an
 * automatic-save error.
 *
 * Parameters:
 *   document — document to write back to its path.
 *
 * Returns: nothing.
 */

void Cedit.automaticSave(EditorDocument document) {
    if (!presented || automaticSaving || changingDocuments || commandsBlocked()
            ||
            document == null || document.path.equals("")
                    || !document.view.modified()) {
        return
    }
    automaticSaving = true
    if (!writeDocument(document, document.path)) {
        document.automaticSaveError = status.text()
        hasAutomaticSaveErrors = true
    }
    automaticSaving = false
}

/*
 * Cedit.automaticSaveErrors
 *
 * Purpose: Collect automatic-save error text from the open documents.
 *
 * Parameters:
 *   none.
 *
 * Returns: joined error text, or empty when none is pending.
 */

String Cedit.automaticSaveErrors() {
    if (!hasAutomaticSaveErrors) {
        return("")
    }
    String errors = ""
    int64 index = 0
    while (index < documents.length) {
        EditorDocument document = documents[index] as EditorDocument
        if (!document.automaticSaveError.equals("")) {
            errors.append(format("  {}", document.automaticSaveError))
        }
        index = index + 1
    }
    return(errors)
}

/*
 * Cedit.recomputeAutomaticSaveErrors
 *
 * Purpose: Scan open documents for a stored automatic-save error.
 *
 * Parameters:
 *   none.
 *
 * Returns: true when any open document has an automatic-save error.
 */

bool Cedit.recomputeAutomaticSaveErrors() {
    int64 index = 0
    while (index < documents.length) {
        EditorDocument document = documents[index] as EditorDocument
        if (!document.automaticSaveError.equals("")) {
            return(true)
        }
        index = index + 1
    }
    return(false)
}

/*
 * Cedit.windowFocusChanged
 *
 * Purpose: When the window gains focus, check files on disk. When it loses
 * focus, save documents if that preference is on.
 *
 * Parameters:
 *   active — true when the window is focused.
 *
 * Returns: nothing.
 */

void Cedit.windowFocusChanged(bool active) {
    if (active) {
        checkDiskChange()
    }
    if (active || !presented || window.disposed()
            || !settings.saveOnWindowLoss) {
        return
    }
    int64 index = 0
    while (index < documents.length) {
        automaticSave(documents[index] as EditorDocument)
        index = index + 1
    }
    updateStatus()
}

/*
 * Cedit.refreshTab
 *
 * Purpose: Set the notebook page title when the document label changed.
 *
 * Parameters:
 *   document — document whose tab label to show.
 *
 * Returns: nothing.
 */

void Cedit.refreshTab(EditorDocument document) {
    String title = document.tabTitle()
    if (title.equals(document.lastTitle)) {
        return
    }
    document.lastTitle = title
    int64 index = 0
    while (index < documents.length) {
        EditorDocument item = documents[index] as EditorDocument
        if (item == document) {
            notebook.setPageTitle(index, title)
            return
        }
        index = index + 1
    }
}

/*
 * Cedit.updateStatusText
 *
 * Purpose: Show line, column, the modified flag, and automatic-save errors.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.updateStatusText() {
    if (status == null || window.disposed() || changingDocuments) {
        return
    }
    EditorDocument document = currentDocument()
    if (document == null) {
        return
    }
    String message = format("Ln {}, Col {}", document.view.line(),
            document.view.column())
    if (document.view.modified()) {
        message.append("  Modified")
    }
    message.append(automaticSaveErrors())
    status.setText(message)
}

/*
 * Cedit.updateStatus
 *
 * Purpose: Refresh the menu and the status bar for the current document.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.updateStatus() {
    if (window == null || window.disposed() || changingDocuments) {
        return
    }
    updateMenu()
    updateStatusText()
}

/*
 * Cedit.updateSelectionActions
 *
 * Purpose: Enable Cut, Copy, and Format Selection when the current
 * document has a selection.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.updateSelectionActions() {
    if (menu == null || window.disposed()) {
        return
    }
    EditorDocument document = currentDocument()
    bool selected = (menuReady && document != null
            && document.view.hasSelection())
    if (selected != menuSelected) {
        menuSelected = selected
        menu.setItemEnabled(cutItem, selected)
        menu.setItemEnabled(copyItem, selected)
    }
    if (formatSelectionItem != 0) {
        menu.setItemEnabled(formatSelectionItem, selected)
    }
}

/*
 * Cedit.updateEditActions
 *
 * Purpose: Enable Undo, Redo, Cut, Copy, and Format Selection to match
 * the current document.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.updateEditActions() {
    if (menu == null || window.disposed()) {
        return
    }
    EditorDocument document = currentDocument()
    bool editable = menuReady && document != null
    bool canUndo = false
    bool canRedo = false
    bool selected = false
    if (editable) {
        canUndo = document.view.canUndo()
        canRedo = document.view.canRedo()
        selected = document.view.hasSelection()
    }
    if (!menuInitialized || canUndo != menuCanUndo) {
        menuCanUndo = canUndo
        menu.setItemEnabled(undoItem, canUndo)
    }
    if (!menuInitialized || canRedo != menuCanRedo) {
        menuCanRedo = canRedo
        menu.setItemEnabled(redoItem, canRedo)
    }
    if (!menuInitialized || selected != menuSelected) {
        menuSelected = selected
        menu.setItemEnabled(cutItem, selected)
        menu.setItemEnabled(copyItem, selected)
    }
    if (formatSelectionItem != 0) {
        menu.setItemEnabled(formatSelectionItem, selected)
    }
}

/*
 * Cedit.updateMenu
 *
 * Purpose: Enable file, project, document, and view items from command
 * readiness, an open project, and whether quit is allowed.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.updateMenu() {
    if (menu == null || status == null || window.disposed()) {
        return
    }
    bool ready = !commandsBlocked()
    EditorDocument document = currentDocument()
    bool editable = ready && document != null
    bool quit = fileDialog == null
    bool projectActive = ready && activeProject != null

    if (!menuInitialized || ready != menuReady) {
        menuReady = ready
        menu.setItemEnabled(newItem, ready)
        menu.setItemEnabled(openItem, ready)
        menu.setItemEnabled(openFolderItem, ready)
        project.sidebar.setSensitive(ready)
        menu.setItemEnabled(projectNewItem, ready)
        menu.setItemEnabled(projectOpenItem, ready)
        findRow.setSensitive(ready)
        replaceRow.setSensitive(ready)
        optionsRow.setSensitive(ready)
    }

    if (!menuInitialized || quit != menuQuit) {
        menuQuit = quit
        menu.setItemEnabled(quitItem, quit)
        menu.setItemEnabled(aboutItem, quit)
        confirmChoices.setSensitive(quit)
        notebook.setSensitive(quit)
        closeChoices.setSensitive(quit)
    }

    if (!menuInitialized || projectActive != menuProjectActive) {
        menuProjectActive = projectActive
        int64 projectIndex = 0
        while (projectIndex < projectItems.length) {
            menu.setItemEnabled(
                    projectItems[projectIndex] as int64,
                    projectActive)
            projectIndex = projectIndex + 1
        }
        menu.setItemEnabled(projectCloseItem, projectActive)
    }

    if (!menuInitialized || editable != menuEditable) {
        menuEditable = editable
        int64 index = 0
        while (index < documentItems.length) {
            menu.setItemEnabled(documentItems[index] as int64, editable)
            index = index + 1
        }
    }
    updateEditActions()
    syncViewMenu()
    menuInitialized = true
}

/*
 * Cedit.workspaceNeedsSave
 *
 * Purpose: Report whether the active writable workspace differs from its
 * saved text.
 *
 * Parameters:
 *   none.
 *
 * Returns: true when that writable workspace text is unsaved.
 */

bool Cedit.workspaceNeedsSave() {
    return(activeProject != null && activeProject.workspaceWritable &&
            !activeProject.workspaceText.equals(
            activeProject.workspaceOriginal))
}

/*
 * Cedit.requestClose
 *
 * Purpose: Snapshot recoveries, then hold the window for unsaved work or
 * allow it to close.
 *
 * Parameters:
 *   none.
 *
 * Returns: true when the close is held; false when the window may close.
 */

bool Cedit.requestClose() {
    writeAllRecoveries()
    if (savePending || projectSaves > 0) {
        closeAfterSave = true
        status.setText("Waiting for settings to save")
        return(true)
    }
    if (allowWindowClose) {
            // Checked synchronously so window.close() is never re-entered from
            // this handler.
        if (!quitReady && workspaceNeedsSave()) {
            writeProject(activeProject, false, true, "quit")
            return(true)
        }
        closePreferencesWindows()
        return(false)
    }
    if (fileDialog != null) {
        fileDialog.cancel()
        fileDialog = null
        dialogDocument = null
        dialogClosing = false
        chooserPurpose = ""
    }
    if (!confirmOp.equals("")) {
        confirmOp = ""
        confirmChoices.setVisible(false)
    }
    switchOp = ""
    nextProject = null
    nextFolder = ""
    if (activeProject != null) {
        activeProject.workspaceText = captureWorkspace(activeProject.root,
                activeProject.root)
    }

    int64 index = 0
    while (index < documents.length) {
        EditorDocument document = documents[index] as EditorDocument
        if (document.view.modified()) {
            pendingCloseAll = true
            pendingCloseDocument = null
            closeChoices.setVisible(true)
            status.setText("Unsaved changes: Save, Discard, or Cancel closing")
            updateMenu()
            return(true)
        }
        index = index + 1
    }

    if (workspaceNeedsSave()) {
        allowWindowClose = true
        writeProject(activeProject, false, true, "quit")
        return(true)
    }
    return(false)
}

/*
 * Cedit.closePreferencesWindows
 *
 * Purpose: Dispose the search, about, configure, and preferences windows.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.closePreferencesWindows() {
    closeSearchDialog()
    if (aboutWindow != null && !aboutWindow.disposed()) {
        aboutWindow.setVisible(false)
        aboutWindow.dispose()
    }
    if (configureWindow != null && !configureWindow.disposed()) {
        configureWindow.setVisible(false)
        configureWindow.dispose()
    }
    if (preferencesWindow != null && !preferencesWindow.disposed()) {
        hidePreferences()
        preferencesWindow.dispose()
    }
}

/*
 * Cedit.closeAll
 *
 * Purpose: Begin closing every document tab when commands are allowed.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.closeAll() {
    if (commandsBlocked()) {
        return
    }
    closingAll = true
    closeNextInBatch()
}

