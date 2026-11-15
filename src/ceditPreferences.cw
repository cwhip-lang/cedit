/*
 * src/ceditPreferences.cw — Preferences window pages, edits, and reset.
 *
 * Created: 2026-11-15
 * Author: Auto
 *
 * Changelog:
 *   2026-11-15  Split from ceditApplyDocumentSettings.cw.
 */

/*
 * Hide the preferences window without destroying it.
 *
 * Purpose: When the window exists, stop recording, cancel a pending reset,
 * and hide it.
 *
 * Parameters:
 *   none.
 *
 * Returns: true (consume the close request).
 */

bool Cedit.hidePreferences() {
    if (preferencesWindow == null || preferencesWindow.disposed()) {
        return(true)
    }
    stopRecording()
    cancelPreferencesReset()
    preferencesWindow.setVisible(false)
    return(true)
}

/*
 * Stop keyboard-shortcut recording.
 *
 * Purpose: Cancel recording on every keyboard preference row.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.stopRecording() {
    int64 i = 0
    while (i < keyboardRows.length) {
        (keyboardRows[i] as KeyboardPreference).cancelRecording()
        i = i + 1
    }
}

/*
 * Show the Editor preferences page.
 *
 * Purpose: Stop recording and cancel a pending reset, then show the Editor
 * page and present the window.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.showEditorPreferences() {
    hidePreferences()
    editorPreferences.setVisible(true)
    keyboardPreferences.setVisible(false)
    startupPreferences.setVisible(false)
    preferencesWindow.present()
}

/*
 * Show the Keyboard preferences page.
 *
 * Purpose: Build shortcut rows on first use, then show the Keyboard page
 * and present the window.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.showKeyboardPreferences() {
    hidePreferences()

    if (keyboardRows.length == 0) {
        int64 i = 0
        while (i < settings.commands.length) {
            KeyboardPreference row = KeyboardPreference(settings,
                    settings.commands[i] as CommandBinding,
                    _self().keyboardSettingsChanged, _self().stopRecording,
                            keyboardRowsBox, i)
            keyboardRows.append(row)
            i = i + 1
        }
    }

    editorPreferences.setVisible(false)
    keyboardPreferences.setVisible(true)
    startupPreferences.setVisible(false)
    preferencesWindow.present()
}

/*
 * Open project configuration from preferences.
 *
 * Purpose: Show Configure Project when a project is open and commands are
 * allowed.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.showProjectPreferences() {
    if (activeProject == null || commandsBlocked()) {
        return
    }
    showConfigure()
}

/*
 * Show the Startup preferences page.
 *
 * Purpose: Stop recording and cancel a pending reset, then show the
 * Startup page and present the window.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.showStartupPreferences() {
    hidePreferences()
    editorPreferences.setVisible(false)
    keyboardPreferences.setVisible(false)
    startupPreferences.setVisible(true)
    preferencesWindow.present()
}

/*
 * Filter the keyboard command list.
 *
 * Purpose: Show rows whose command name or id contains the query,
 * ignoring case.
 *
 * Parameters:
 *   query — text from the command search box.
 *
 * Returns: nothing.
 */

void Cedit.filterCommands(String query) {
    int64 i = 0
    while (i < keyboardRows.length) {
        KeyboardPreference row = keyboardRows[i] as KeyboardPreference
        row.setVisible(row.binding.name.toLower().contains(query.toLower()) ||
                               row.binding.id.contains(query.toLower()))
        i = i + 1
    }
}

/*
 * Parse a bounded integer from a preference field.
 *
 * Purpose: Accept one to three digits inside the inclusive range. Reject
 * empty, non-numeric, and out-of-range text.
 *
 * Parameters:
 *   text — field text to parse.
 *   minimum — lowest allowed value.
 *   maximum — highest allowed value.
 *
 * Returns: the integer, or -1 when the text is rejected.
 */

int64 Cedit.preferenceNumber(String text, int64 minimum, int64 maximum) {
        // Allow up to 3 digits so right_margin (0-512) can be entered.
    if (text.length == 0 || text.length > 3) {
        return(-1)
    }
    int64 i = 0
    while (i < text.length) {
        if (!"0123456789".contains(byteSpan(text, i, i + 1))) {
            return(-1)
        }
        i = i + 1
    }
    int64 number = text.toInt64()
    if (number < minimum || number > maximum) {
        return(-1)
    }
    return(number)
}

/*
 * Apply an editor checkbox change.
 *
 * Purpose: Reread the editor controls and save them.
 *
 * Parameters:
 *   active — new checkbox state.
 *
 * Returns: nothing.
 */

void Cedit.editorCheckChanged(bool active) {
    editorSettingChanged("")
}

/*
 * Apply an editor preference field change.
 *
 * Purpose: Validate font, size, tabs, and margin, then save. Copy a
 * project line-number override, and relaunch the language server if
 * its command changed.
 *
 * Parameters:
 *   text — text from the changed entry.
 *
 * Returns: nothing.
 */

void Cedit.editorSettingChanged(String text) {
    if (refreshingPreferences) {
        return
    }
    if (fontEntry == null || sizeEntry == null || tabsEntry == null
            || marginEntry == null) {
        return
    }
    String problem = settings.fontError(fontEntry.text())
    int64 size = preferenceNumber(sizeEntry.text(), 6, 72)
    int64 tabs = preferenceNumber(tabsEntry.text(), 1, 16)
    int64 margin = preferenceNumber(marginEntry.text(), 0, 512)
    if (size < 0) {
        problem = "Font size must be an integer from 6 to 72"
    }
    if (tabs < 0) {
        problem = "Tab width must be an integer from 1 to 16"
    }
    if (margin < 0) {
        problem = "Right margin must be an integer from 0 to 512"
    }
    if (!problem.equals("")) {
        preferencesMessage.setText(problem)
        return
    }
    settings.fontFamily = fontEntry.text()
    settings.fontSize = size
    settings.tabWidth = tabs
    settings.rightMargin = margin
    settings.insertSpaces = spacesCheck.active()
    settings.lineNumbers = numbersCheck.active()
    if (activeProject != null && activeProject.hasNumbers) {
        activeProject.lineNumbers = settings.lineNumbers
        if (activeProject.writable && projectSaves == 0 && projectOp.equals(
                "")) {
            writeProject(activeProject, true, false, "configure")
        }
    }
    settings.wrap = wrapCheck.active()
    settings.highlightLine = highlightCheck.active()
    settings.saveOnTabLoss = saveTabCheck.active()
    settings.saveOnWindowLoss = saveWindowCheck.active()
    settings.stripTrailingSpaces = stripCheck.active()
    settings.autoCompleteBrackets = bracketsCheck.active()
    settings.autoIndent = autoIndentCheck.active()
    settings.showUnsavedMarks = unsavedMarksCheck.active()
    if (lspEntry != null && !lspEntry.text().equals(settings.lspCommand)) {
        settings.lspCommand = lspEntry.text()
        if (client != null) {
            client.launch(settings.lspCommand)
        }
    }
    settingsChanged()
}

/*
 * Copy the current preferences into the global settings file.
 *
 * Purpose: Write a mirror of the serialized settings. Show a diagnostic
 * when the write fails.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.saveGlobalClicked() {
    if (refreshingPreferences || commandsBlocked()) {
        return
    }

    if (!writeMirroredGlobal(settings.serialize())) {
        if (preferencesMessage != null) {
            preferencesMessage.setText(diagnostic("CEDIT2001", format(
                    "Could not update global settings at {}",
                    settings.globalPath)))
        }
        return
    }

    if (preferencesMessage != null) {
        preferencesMessage.setText(format(
                "Copied preferences to {}",
                settings.globalPath))
    }
    refreshSettingsPathLabel()
}

/*
 * Read a settings file from disk.
 *
 * Purpose: Return the file contents. A missing or unreadable path yields
 * an empty string.
 *
 * Parameters:
 *   path — settings file to read.
 *
 * Returns: the file text, or empty on failure.
 */

String Cedit.readSettingsDisk(String path) {
    if (!System.FileSystem().isFile(path)) {
        return("")
    }
    System.File file = null
    try {
        file = System.File(path, "r")
    }
        except(Exception) {
        return("")
    }
    String text = ""
    try {
        text = file.readAll()
    }
        except(Exception) {
        file.close()
        return("")
    }
    file.close()
    return(text)
}

/*
 * Ask to reset Editor preferences.
 *
 * Purpose: Show the reset confirmation for the Editor section.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.resetEditorPreferences() {
    resetSection = "Editor"
    resetChoices.setVisible(true)
}

/*
 * Ask to reset Keyboard preferences.
 *
 * Purpose: Show the reset confirmation for the Keyboard section.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.resetKeyboardPreferences() {
    resetSection = "Keyboard"
    resetChoices.setVisible(true)
}

/*
 * Cancel a pending preferences reset.
 *
 * Purpose: Clear the selected section and hide the confirmation.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.cancelPreferencesReset() {
    resetSection = ""
    resetChoices.setVisible(false)
}

