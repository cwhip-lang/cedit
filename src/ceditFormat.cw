/*
 * src/ceditFormat.cw — format the current buffer through the language server.
 *
 * Created: 2026-11-15
 * Author: Auto
 *
 * Changelog:
 *   2026-11-15  Initial file.
 */

/*
 * Cedit.formatDocument
 *
 * Purpose: Ask the language server to format the whole current buffer.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing. The buffer changes when a formatting result arrives.
 */

void Cedit.formatDocument() {
    if (commandsBlocked()) {
        return
    }
    if (client == null) {
        status.setText("Language server is not running")
        return
    }
    client.requestFormat(currentDocument(), false)
}

/*
 * Cedit.formatSelection
 *
 * Purpose: Ask the language server to format the current selection.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing. With no selection the buffer is unchanged.
 */

void Cedit.formatSelection() {
    if (commandsBlocked()) {
        return
    }
    if (client == null) {
        status.setText("Language server is not running")
        return
    }
    client.requestFormat(currentDocument(), true)
}
