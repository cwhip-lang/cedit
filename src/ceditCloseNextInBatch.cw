/*
 * src/ceditCloseNextInBatch.cw - Close batch, disk-change, and pending-close
 * paths.
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
 * Continue closing every document.
 *
 * Purpose: If a close-all is in progress, prompt for the next modified
 * tab, or close the rest and open a new untitled document.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.closeNextInBatch() {
    if (!closingAll) {
        return
    }
    EditorDocument dirty = firstModifiedDocument()
    if (dirty != null) {
        pendingCloseDocument = dirty
        activateDocument(dirty)
        closeChoices.setVisible(true)
        status.setText(format("Unsaved changes in {}: Save, Discard, or Cancel",
                dirty.tabTitle()))
        updateMenu()
        return
    }
    closeAllDocuments()
    closingAll = false
    pendingCloseDocument = null
    closeChoices.setVisible(false)
    newDocument()
    status.setText("Closed all documents")
    updateMenu()
}

/*
 * Close the active project.
 *
 * Purpose: Capture the workspace and start a close save. Do nothing while
 * commands are blocked or no project is open.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.closeProject() {
    if (commandsBlocked()) {
        return
    }
    if (activeProject == null) {
        status.setText("No project is open")
        return
    }
    activeProject.workspaceText = captureWorkspace(activeProject.root,
            activeProject.root)
    writeProject(activeProject, false, true, "close")
}

/*
 * Close the current document.
 *
 * Purpose: Close the current tab, prompting when it has unsaved changes.
 * Do nothing while commands are blocked.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.closeCurrentDocument() {
    if (commandsBlocked()) {
        return
    }
    EditorDocument document = currentDocument()
    closeDocument(document)
}

/*
 * Read a document file and note when it is missing.
 *
 * Purpose: Load the file into a string. Set diskMissing when the file is
 * absent or unreadable.
 *
 * Parameters:
 *   path — file to read.
 *
 * Returns: the file text, or empty when the read fails.
 */

String Cedit.readDiskFile(String path) {
    diskMissing = !System.FileSystem().isFile(path)
    if (diskMissing) {
        return("")
    }
    System.File input = null
    try {
        input = System.File(path, "r")
    }
        except(Exception) {
        diskMissing = true
        return("")
    }
    String text = ""
    try {
        text = input.readAll()
    }
        except(Exception) {
        input.close()
        diskMissing = true
        return("")
    }
    input.close()
    if (!System.System().lastError().equals("")) {
        diskMissing = true
        return("")
    }
    return(text)
}

/*
 * Dismiss the disk-change prompt.
 *
 * Purpose: Clear the prompted document, hide the choices, and update the menu.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.clearDiskPrompt() {
    diskDocument = null
    if (diskChoices != null) {
        diskChoices.setVisible(false)
    }
    updateMenu()
}

/*
 * Prompt when the current file changed on disk.
 *
 * Purpose: Compare the current file once the window is shown and no prompt
 * is up. Offer Reload, Save, or Close when the file is missing or
 * different.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.checkDiskChange() {
    if (diskDocument != null || changingDocuments || !presented) {
        return
    }
    EditorDocument document = currentDocument()
    if (document == null || document.path.equals("")) {
        return
    }
    String disk = readDiskFile(document.path)
    if (diskMissing || !disk.equals(document.diskText)) {
        diskDocument = document
        diskChoices.setVisible(true)
        status.setText(format("{} changed on disk. Reload, Save, or Close",
                document.tabTitle()))
        updateMenu()
    }
}

/*
 * Replace the prompted document with the file on disk.
 *
 * Purpose: Reload the prompted or current document, mark it saved, and
 * tell the language server. Refuse when the file is not readable.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.reloadFromDisk() {
    EditorDocument document = diskDocument
    if (document == null) {
        document = currentDocument()
    }
    if (document == null || document.path.equals("")) {
        return
    }
    String disk = readDiskFile(document.path)
    if (diskMissing) {
        status.setText("Cannot reload; the file is not readable")
        return
    }
    document.view.setText(disk)
    document.view.markSaved()
    document.diskText = disk
    clearUnsavedMarks(document)
    clearDiskPrompt()
    refreshTab(document)
    if (client != null && client.ready) {
        client.sendChange(document)
    }
    status.setText("Reloaded")
}

/*
 * Save the prompted document over the file on disk.
 *
 * Purpose: Write that document to its path and dismiss the prompt when the
 * write succeeds.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.saveOverDisk() {
    EditorDocument document = diskDocument
    if (document == null) {
        return
    }
    if (writeDocument(document, document.path)) {
        clearDiskPrompt()
    }
}

/*
 * Close the document that changed on disk.
 *
 * Purpose: Dismiss the disk prompt and remove that document without
 * another save prompt.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.closeDiskDocument() {
    EditorDocument document = diskDocument
    clearDiskPrompt()
    if (document != null) {
        removeDocument(document)
    }
}

/*
 * Reload the current file, or prompt when that would lose edits.
 *
 * Purpose: If the buffer is modified or the file differs, show the
 * disk-change choices. Otherwise report that the tab is current.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.reloadCurrent() {
    if (diskDocument != null) {
        return
    }
    if (commandsBlocked()) {
        return
    }
    EditorDocument document = currentDocument()
    if (document == null || document.path.equals("")) {
        status.setText("No file to reload")
        return
    }
    String disk = readDiskFile(document.path)
    if (document.view.modified() || diskMissing || !disk.equals(
            document.diskText)) {
        diskDocument = document
        diskChoices.setVisible(true)
        status.setText(format("{} changed on disk. Reload, Save, or Close",
                document.tabTitle()))
        updateMenu()
        return
    }
    status.setText("Already current")
}

/*
 * Close one document.
 *
 * Purpose: Prompt when the document is modified; otherwise remove its tab.
 * Do nothing while commands are blocked.
 *
 * Parameters:
 *   document — tab to close.
 *
 * Returns: nothing.
 */

void Cedit.closeDocument(EditorDocument document) {
    if (commandsBlocked()) {
        return
    }
    if (document == null) {
        return
    }
    if (document.view.modified()) {
        pendingCloseDocument = document
        pendingCloseAll = false
        closeChoices.setVisible(true)
        status.setText(format("Unsaved changes in {}: Save, Discard, or Cancel",
                                  document.tabTitle()))
        updateMenu()
        return
    }
    removeDocument(document)
}

/*
 * Remove a document tab immediately.
 *
 * Purpose: Drop the page, notify the language server, and focus the
 * next tab. Outside a batch close, replace the last tab with a new
 * untitled document.
 *
 * Parameters:
 *   document — tab to remove.
 *
 * Returns: nothing.
 */

void Cedit.removeDocument(EditorDocument document) {

    int64 index = 0
    while (index < documents.length) {

        if ((documents[index] as EditorDocument) == document) {
            if (client != null) {
                client.sendClose(document.path)
            }
            changingDocuments = true
            notebook.remove(document.scroller)
            document.scroller.dispose()
            list remaining = []
            int64 itemIndex = 0
            while (itemIndex < documents.length) {
                EditorDocument item = documents[itemIndex] as EditorDocument
                if (item != document) {
                    remaining.append(item)
                }
                itemIndex = itemIndex + 1
            }
            documents = remaining
            focusedDocument = currentDocument()
            changingDocuments = false
            if (hasAutomaticSaveErrors) {
                hasAutomaticSaveErrors = recomputeAutomaticSaveErrors()
            }
            if (pendingCloseDocument == document) {
                pendingCloseDocument = null
            }
            if (!pendingCloseAll) {
                closeChoices.setVisible(false)
            }
            if (documents.length == 0 && !pendingCloseAll && !closingAll) {
                newDocument()
            }
            else {
                updateStatus()
                EditorDocument next = currentDocument()
                if (next != null && !pendingCloseAll) {
                    next.view.focus()
                }
            }
                // The closing shortcut's controller must unwind before
                // restoring focus.
            if (!pendingCloseAll && !closingAll) {
                Gtk.Application().post(_self().focusAfterClose)
            }
            return
        }

        index = index + 1
    }

}

/*
 * Focus the current document after a tab closes.
 *
 * Purpose: Focus the current view unless the window is gone, commands are
 * blocked, or the search dialog is open.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.focusAfterClose() {
    if (window.disposed() || commandsBlocked() || searchDialogOpen) {
        return
    }
    EditorDocument document = currentDocument()
    if (document != null) {
        document.view.focus()
    }
}

/*
 * Find the first document with unsaved changes.
 *
 * Purpose: Scan open documents from the start of the list.
 *
 * Parameters:
 *   none.
 *
 * Returns: that document, or null when every tab is clean.
 */

EditorDocument Cedit.firstModifiedDocument() {
    int64 index = 0
    while (index < documents.length) {
        EditorDocument document = documents[index] as EditorDocument
        if (document.view.modified()) {
            return(document)
        }
        index = index + 1
    }
    return(null)
}

/*
 * Save the document that is waiting to close.
 *
 * Purpose: Save the tab waiting to close, or the next modified tab in
 * a close-all. Open Save As when untitled, and stop when the write
 * fails.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.savePendingClose() {
    if (fileDialog != null) {
        return
    }
    EditorDocument document = pendingCloseDocument
    if (pendingCloseAll) {
        document = firstModifiedDocument()
    }
    if (document == null) {
        finishPendingClose()
        return
    }
    activateDocument(document)
    String destination = document.path
    if (destination.equals("")) {
        chooseSave(document, true)
        return
    }
    if (!writeDocument(document, destination)) {
        return
    }
    continueSavedClose()
}

/*
 * Continue a close after a successful save.
 *
 * Purpose: Advance a close-all batch, finish a single close, or ask about
 * the remaining modified tabs.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.continueSavedClose() {
    if (closingAll) {
        pendingCloseDocument = null
        closeNextInBatch()
        return
    }
    if (!pendingCloseAll) {
        finishPendingClose()
        return
    }
    if (firstModifiedDocument() == null) {
        finishPendingClose()
    }
    else {
        status.setText("Saved. Save or discard the remaining modified tabs")
    }
}

/*
 * Discard unsaved changes and continue closing.
 *
 * Purpose: Drop the pending tab in a close-all, continue a project switch,
 * close the window, or remove the single pending document.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.discardPendingClose() {

    if (closingAll) {
        EditorDocument document = pendingCloseDocument
        if (document == null) {
            document = firstModifiedDocument()
        }
        pendingCloseDocument = null
        if (document != null) {
            removeDocument(document)
        }
        closeNextInBatch()
        return
    }

    if (pendingCloseAll && !switchOp.equals("")) {
        pendingCloseAll = false
        closeChoices.setVisible(false)
        continueSwitch(switchOp)
        return
    }
    if (pendingCloseAll) {
        window.setVisible(false)
        closeAllDocuments()
        pendingCloseAll = false
        pendingCloseDocument = null
        closeChoices.setVisible(false)
        allowWindowClose = true
        window.close()
        return
    }
    EditorDocument document = pendingCloseDocument
    if (document != null) {
        removeDocument(document)
    }
    pendingCloseDocument = null
    closeChoices.setVisible(false)
}

/*
 * Cancel a close that is waiting on unsaved changes.
 *
 * Purpose: Abort a pending project switch, clear close-all state, and hide
 * the save prompt.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.cancelPendingClose() {
    if (!switchOp.equals("")) {
        switchOp = ""
        nextProject = null
        status.setText("Cancelled opening the project")
    }
    pendingCloseDocument = null
    pendingCloseAll = false
    closingAll = false
    closeChoices.setVisible(false)
    updateStatus()
}

/*
 * Finish the pending close.
 *
 * Purpose: Continue a project switch, close the window, or remove the
 * single pending document.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.finishPendingClose() {
    if (pendingCloseAll && !switchOp.equals("")) {
        pendingCloseAll = false
        closeChoices.setVisible(false)
        continueSwitch(switchOp)
        return
    }
    if (pendingCloseAll) {
        pendingCloseAll = false
        pendingCloseDocument = null
        closeChoices.setVisible(false)
        allowWindowClose = true
        window.close()
        return
    }
    EditorDocument document = pendingCloseDocument
    pendingCloseDocument = null
    closeChoices.setVisible(false)
    if (document != null) {
        removeDocument(document)
    }
}

