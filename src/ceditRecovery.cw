/*
 * src/ceditRecovery.cw - Dirty-buffer snapshots under .cedit/recovery.
 *
 * Created: 2026-10-30
 * Author: Auto
 *
 * Changelog:
 *   2026-10-30  Initial file.
 *   2026-11-13  CODING headers and method comments.
 *   2026-11-15  Apply the revised coding standard.
 */

/*
 * Cedit.recoveryDir
 *
 * Purpose: Return the active project's .cedit/recovery directory.
 *
 * Parameters:
 *   none.
 *
 * Returns: the recovery directory, or empty when no project is open.
 */

String Cedit.recoveryDir() {
    if (activeProject == null) {
        return("")
    }
    return(System.FileSystem().join(activeProject.root, ".cedit/recovery"))
}

/*
 * Cedit.recoveryPathFor
 *
 * Purpose: Build a .txt recovery path by sanitizing the document path.
 *
 * Parameters:
 *   documentPath — document path encoded into the file name.
 *
 * Returns: the snapshot path, or empty when recovery is unavailable.
 */

String Cedit.recoveryPathFor(String documentPath) {
    String dir = recoveryDir()
    if (dir.equals("") || documentPath.equals("")) {
        return("")
    }
    String name = documentPath.replace("/", "_")
    name = name.replace("\\", "_")
    if (name.length > 180) {
        name = byteSpan(name, name.length - 180, name.length)
    }
    return(System.FileSystem().join(dir, format("{}.txt", name)))
}

/*
 * Cedit.ensureRecoveryDir
 *
 * Purpose: Create .cedit and the recovery directory when they are missing.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.ensureRecoveryDir() {
    String dir = recoveryDir()
    if (dir.equals("")) {
        return
    }
    String parent = System.FileSystem().dirname(dir)
    if (!System.FileSystem().isDir(parent)) {
        System.FileSystem().mkdir(parent)
    }
    if (!System.FileSystem().isDir(dir)) {
        System.FileSystem().mkdir(dir)
    }
}

/*
 * Cedit.writeRecovery
 *
 * Purpose: Write a recovery snapshot for a modified named document.
 *
 * Parameters:
 *   document — document to snapshot.
 *
 * Returns: nothing.
 */

void Cedit.writeRecovery(EditorDocument document) {
    if (document == null || document.path.equals("") || !document.view.modified(
            )) {
        return
    }
    String path = recoveryPathFor(document.path)
    if (path.equals("")) {
        return
    }
    ensureRecoveryDir()
    String payload = format("# cedit-recovery: {}\n{}", document.path,
            document.view.text())
    try {
        System.File file = System.File(path, "w")
        file.write(payload)
        file.close()
    }
    except(Exception) {
    }
}

/*
 * Cedit.clearRecovery
 *
 * Purpose: Remove a document's recovery file when one exists.
 *
 * Parameters:
 *   document — document whose snapshot to delete.
 *
 * Returns: nothing.
 */

void Cedit.clearRecovery(EditorDocument document) {
    if (document == null || document.path.equals("")) {
        return
    }
    String path = recoveryPathFor(document.path)
    if (path.equals("")) {
        return
    }
    if (System.FileSystem().isFile(path)) {
        try {
            System.FileSystem().remove(path)
        }
        except(Exception) {
        }
    }
}

/*
 * Cedit.writeAllRecoveries
 *
 * Purpose: Write a recovery snapshot for every open document.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.writeAllRecoveries() {
    int64 i = 0
    while (i < documents.length) {
        writeRecovery(documents[i] as EditorDocument)
        i = i + 1
    }
}

/*
 * Cedit.scheduleRecoveryPoll
 *
 * Purpose: When the window is open, schedule a recovery pass in 15 seconds.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.scheduleRecoveryPoll() {
    if (!presented || window == null || window.disposed()) {
        return
    }
    Gtk.Application().schedule(15000, recoveryPollAction)
}

/*
 * Cedit.recoveryPoll
 *
 * Purpose: Write recovery snapshots, then schedule the next pass.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.recoveryPoll() {
    if (!presented || window == null || window.disposed()) {
        return
    }
    writeAllRecoveries()
    scheduleRecoveryPoll()
}

/*
 * Cedit.readRecoveryBody
 *
 * Purpose: Return the saved buffer when the recovery header names the
 * expected document.
 *
 * Parameters:
 *   recoveryFile — path of the snapshot to read.
 *   expectedPath — document path required in the header.
 *
 * Returns: the saved buffer, or empty when the header does not match.
 */

String Cedit.readRecoveryBody(String recoveryFile, String expectedPath) {
    try {
        System.File file = System.File(recoveryFile, "r")
        String data = file.readAll()
        file.close()
        String marker = "# cedit-recovery: "
        if (!data.startsWith(marker)) {
            return("")
        }
        int64 nl = data.find("\n")
        if (nl < 0) {
            return("")
        }
        String headerPath = byteSpan(data, marker.length, nl)
        if (!headerPath.equals(expectedPath)) {
            return("")
        }
        return(byteSpan(data, nl + 1, data.length))
    }
    except(Exception) {
        return("")
    }
}

/*
 * Cedit.offerRecoveryForDocuments
 *
 * Purpose: Ask to restore the first recovery that differs from the file on
 * disk, and drop snapshots that already match.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.offerRecoveryForDocuments() {
    if (activeProject == null) {
        return
    }
    if (!confirmOp.equals("")) {
        return
    }

    int64 i = 0
    while (i < documents.length) {

        EditorDocument document = documents[i] as EditorDocument
        if (!document.path.equals("")) {

            String recovery = recoveryPathFor(document.path)
            if (System.FileSystem().isFile(recovery)) {

                String body = readRecoveryBody(recovery, document.path)
                if (!body.equals("") && !body.equals(document.diskText)) {
                    pendingRecoveryDocument = document
                    pendingRecoveryText = body
                        // Use the path basename; tabTitle may already include
                        // "*".
                    askConfirm("recover-buffer",
                            format(
                            "Recover unsaved edits for {}?",
                            document.baseName),
                            "Restore")
                    return
                }

                clearRecovery(document)
            }

        }

        i = i + 1
    }

}

/*
 * Cedit.acceptRecovery
 *
 * Purpose: Put the pending recovery into the buffer, leave it modified, and
 * offer the next snapshot.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.acceptRecovery() {
    if (pendingRecoveryDocument == null) {
        return
    }
    EditorDocument document = pendingRecoveryDocument
    String body = pendingRecoveryText
        // Remove the snapshot before re-scanning; otherwise the same prompt
        // returns.
    clearRecovery(document)
    pendingRecoveryDocument = null
    pendingRecoveryText = ""
    document.view.setText(body)
        // Leave modified so Save is required; do not overwrite disk.
    activateDocument(document)
    updateUnsavedMarks(document)
    refreshTab(document)
    status.setText("Restored unsaved buffer; save to keep changes")
    offerRecoveryForDocuments()
}

/*
 * Cedit.discardRecovery
 *
 * Purpose: Delete the pending recovery, keep the saved file, and offer the
 * next snapshot.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.discardRecovery() {
    if (pendingRecoveryDocument != null) {
        clearRecovery(pendingRecoveryDocument)
        pendingRecoveryDocument = null
        pendingRecoveryText = ""
        status.setText("Discarded recovery; kept saved file")
    }
    offerRecoveryForDocuments()
}
