/*
 * src/ceditApplyDocumentSettings.cw — Apply editor settings and read or
 * write the settings files.
 *
 * Created: 2026-10-29
 * Author: Auto
 *
 * Changelog:
 *   2026-10-29  Initial file.
 *   2026-11-13  CODING headers and method comments.
 *   2026-11-15  Apply the revised coding standard.
 *   2026-11-15  Move the preferences window into ceditPreferences.cw.
 */

/*
 * Cedit.applyDocumentSettings
 *
 * Purpose: Push font/tabs/view prefs onto one document (project overrides win).
 *
 * Parameters:
 *   document.
 *
 * Returns: nothing.
 */

void Cedit.applyDocumentSettings(EditorDocument document) {

    String font = settings.fontFamily
    int64 size = settings.fontSize
    int64 tabs = settings.tabWidth
    bool spaces = settings.insertSpaces
    bool numbers = settings.lineNumbers
    bool wrapLines = settings.wrap
    bool highlight = settings.highlightLine
    CwhipProject current = activeProject
    if (current != null) {
        if (current.hasFont) {
            font = current.fontFamily
        }
        if (current.hasSize) {
            size = current.fontSize
        }
        if (current.hasTabs) {
            tabs = current.tabWidth
        }
        if (current.hasSpaces) {
            spaces = current.insertSpaces
        }
        if (current.hasNumbers) {
            numbers = current.lineNumbers
        }
        if (current.hasWrap) {
            wrapLines = current.wrap
        }
        if (current.hasHighlight) {
            highlight = current.highlightLine
        }
    }

    document.view.configure(
            font,
            size,
            tabs,
            spaces,
            numbers,
            wrapLines,
            highlight)
    document.view.setShowWhitespace(settings.showWhitespace)
    document.view.setShowLineEnds(settings.showLineEnds)
    document.view.setShowIndentMarkers(settings.showIndentMarkers)
    document.view.setAutoCompleteBrackets(settings.autoCompleteBrackets)
    document.view.setAutoIndent(settings.autoIndent)
    document.view.setSelectedLinesEdit(true)
    if (settings.rightMargin > 0) {
        document.view.setRightMargin(true, settings.rightMargin)
    }
    else {
        document.view.setRightMargin(false, 80)
    }
    if (settings.showUnsavedMarks) {
        updateUnsavedMarks(document)
    }
    else {
        clearUnsavedMarks(document)
    }
    if (document.shortcutRevision == settings.shortcutRevision) {
        return
    }
    document.shortcutRevision = settings.shortcutRevision
    document.view.clearShortcuts()
    document.shortcuts = []
    document.shortcutConflict = settings.legacyConflict

    int64 i = 0
    while (i < settings.commands.length) {

        CommandBinding binding = settings.commands[i] as CommandBinding
        if (binding.trigger.length > 0 && binding.valid) {
            if (document.view.bindShortcut(binding.trigger, binding.action)) {
                document.shortcuts.append(binding.trigger)
            }
            else {
                status.setText(format(
                        "Invalid shortcut trigger: {}",
                        binding.trigger))
            }
        }

        i = i + 1
    }

}

/*
 * Build the preferences window and its pages.
 *
 * Purpose: Create the Editor, Keyboard, Project, and Startup pages, wire
 * their controls, and leave the window hidden.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.createPreferences() {
    preferencesWindow = Gtk.TransientWindow("cedit Preferences")
    preferencesWindow.setTransientFor(window)
    preferencesWindow.setDefaultSize(850, 600)
    Gtk.Box root = Gtk.Box(Gtk.Box.VERTICAL, 8)
    Gtk.Box content = Gtk.Box(Gtk.Box.HORIZONTAL, 12)
    Gtk.Box categories = Gtk.Box(Gtk.Box.VERTICAL, 6)
    Gtk.Button editorCategory = Gtk.Button("Editor")
    Gtk.Button keyboardCategory = Gtk.Button("Keyboard")
    configureProjectButton = Gtk.Button("Project")
    Gtk.Button startupCategory = Gtk.Button("Startup")
    categories.append(editorCategory)
    categories.append(keyboardCategory)
    categories.append(configureProjectButton)
    categories.append(startupCategory)
    editorCategory.onClicked(_self().showEditorPreferences)
    keyboardCategory.onClicked(_self().showKeyboardPreferences)
    configureProjectButton.onClicked(_self().showProjectPreferences)
    startupCategory.onClicked(_self().showStartupPreferences)
    content.append(categories)
    Gtk.Box pages = Gtk.Box(Gtk.Box.VERTICAL, 8)
    pages.setHExpand(true)
    pages.setVExpand(true)
    content.append(pages)
    editorPreferences = Gtk.Box(Gtk.Box.VERTICAL, 6)
    editorPreferences.append(Gtk.Label("Editor"))
    projectNote = Gtk.Label("")
    editorPreferences.append(projectNote)
    fontEntry = preferenceEntry(editorPreferences, "Monospace font family",
            settings.fontFamily)
    sizeEntry = preferenceEntry(editorPreferences, "Font size (6-72 pt)",
            format("{}", settings.fontSize))
    tabsEntry = preferenceEntry(editorPreferences, "Tab width (1-16 columns)",
            format("{}", settings.tabWidth))
    marginEntry = preferenceEntry(editorPreferences,
            "Right margin column (0 = off)",
            format("{}", settings.rightMargin))
    Gtk.Box globalRow = Gtk.Box(Gtk.Box.HORIZONTAL, 6)
    saveGlobalButton = Gtk.Button("Save to global settings")
    saveGlobalButton.setHExpand(false)
    saveGlobalButton.onClicked(_self().saveGlobalClicked)
    globalRow.append(saveGlobalButton)
    editorPreferences.append(globalRow)
    spacesCheck = preferenceCheck("Insert spaces instead of tabs",
            settings.insertSpaces)
    numbersCheck = preferenceCheck("Show line numbers", settings.lineNumbers)
    wrapCheck = preferenceCheck("Wrap long lines", settings.wrap)
    highlightCheck = preferenceCheck("Highlight current line",
            settings.highlightLine)
    saveTabCheck = preferenceCheck("Save on loss of tab focus",
            settings.saveOnTabLoss)
    saveWindowCheck = preferenceCheck("Save on loss of window focus",
            settings.saveOnWindowLoss)
    stripCheck = preferenceCheck("Strip trailing spaces on save",
            settings.stripTrailingSpaces)
    bracketsCheck = preferenceCheck("Auto-close brackets and quotes",
            settings.autoCompleteBrackets)
    autoIndentCheck = preferenceCheck("Auto-indent new lines",
            settings.autoIndent)
    unsavedMarksCheck = preferenceCheck(
            "Mark unsaved changed lines in the gutter",
            settings.showUnsavedMarks)
    lspEntry = preferenceEntry(editorPreferences,
            "Language server (empty, cwhip-lsp, clangd, or a command)",
            settings.lspCommand)
    fontEntry.onChanged(_self().editorSettingChanged)
    sizeEntry.onChanged(_self().editorSettingChanged)
    tabsEntry.onChanged(_self().editorSettingChanged)
    marginEntry.onChanged(_self().editorSettingChanged)
    Gtk.Box editorResetRow = Gtk.Box(Gtk.Box.HORIZONTAL, 6)
    Gtk.Button editorReset = Gtk.Button("Reset Editor to Defaults")
    editorReset.setHExpand(false)
    editorReset.onClicked(_self().resetEditorPreferences)
    editorResetRow.append(editorReset)
    editorPreferences.append(editorResetRow)
    pages.append(editorPreferences)
    keyboardPreferences = Gtk.Box(Gtk.Box.VERTICAL, 6)
    commandSearch = Gtk.Entry("")
    keyboardPreferences.append(Gtk.Label(
            "Search commands; empty binding disables a command"))
    keyboardPreferences.append(commandSearch)
    commandSearch.onChanged(_self().filterCommands)
    Gtk.ScrolledWindow scroll = Gtk.ScrolledWindow()
    scroll.setVExpand(true)
    keyboardRowsBox = Gtk.Grid(6)
    scroll.setChild(keyboardRowsBox)
    keyboardRows = []
    keyboardPreferences.append(scroll)
    Gtk.Box keyboardResetRow = Gtk.Box(Gtk.Box.HORIZONTAL, 6)
    Gtk.Button keyboardReset = Gtk.Button("Reset Keyboard to Defaults")
    keyboardReset.setHExpand(false)
    keyboardReset.onClicked(_self().resetKeyboardPreferences)
    keyboardResetRow.append(keyboardReset)
    keyboardPreferences.append(keyboardResetRow)
    pages.append(keyboardPreferences)
    keyboardPreferences.setVisible(false)
    startupPreferences = Gtk.Box(Gtk.Box.VERTICAL, 6)
    startupPreferences.append(Gtk.Label("Startup"))
    reopenCheck = Gtk.CheckButton("Reopen last project on startup")
    reopenCheck.setActive(settings.reopenLast)
    reopenCheck.onToggled(_self().reopenChanged)
    startupPreferences.append(reopenCheck)
    pages.append(startupPreferences)
    startupPreferences.setVisible(false)
    root.append(content)
    String settingsError = ""
    if (!settings.errors.equals("")) {
        settingsError = diagnostic("CEDIT2001",
                format("{}: {}", settings.path, settings.errors))
    }
    preferencesMessage = Gtk.Label(settingsError)
    root.append(preferencesMessage)
    settingsPathLabel = Gtk.Label(format("Automatically saved to {}",
            settings.path))
    root.append(settingsPathLabel)
    resetChoices = Gtk.Box(Gtk.Box.HORIZONTAL, 6)
    resetChoices.append(Gtk.Label("Reset this section?"))
    confirmResetButton = Gtk.Button("Confirm Reset")
    cancelResetButton = Gtk.Button("Cancel")
    confirmResetButton.onClicked(_self().confirmPreferencesReset)
    cancelResetButton.onClicked(_self().cancelPreferencesReset)
    resetChoices.append(confirmResetButton)
    resetChoices.append(cancelResetButton)
    root.append(resetChoices)
    resetChoices.setVisible(false)
    preferencesWindow.setChild(root)
    preferencesWindow.onCloseRequest(_self().hidePreferences)
    preferencesWindow.setVisible(false)
}

/*
 * Cedit.preferenceEntry
 *
 * Purpose: Add a labeled text row to a preferences page.
 *
 * Parameters:
 *   page — box that receives the row.
 *   label — caption shown beside the entry.
 *   text — initial entry text.
 *
 * Returns: the entry so the caller can read it later.
 */

Gtk.Entry Cedit.preferenceEntry(Gtk.Box page, String label, String text) {
    Gtk.Box row = Gtk.Box(Gtk.Box.HORIZONTAL, 6)
    row.append(Gtk.Label(label))
    Gtk.Entry entry = Gtk.Entry(text)
    entry.setHExpand(true)
    row.append(entry)
    page.append(row)
    return(entry)
}

/*
 * Cedit.preferenceCheck
 *
 * Purpose: Add a check button to the editor preferences page and
 * run editorCheckChanged when it toggles.
 *
 * Parameters:
 *   label — caption on the check button.
 *   active — initial checked state.
 *
 * Returns: the check button.
 */

Gtk.CheckButton Cedit.preferenceCheck(String label, bool active) {
    Gtk.CheckButton check = Gtk.CheckButton(label)
    check.setActive(active)
    check.onToggled(_self().editorCheckChanged)
    editorPreferences.append(check)
    return(check)
}

/*
 * Show the preferences window.
 *
 * Purpose: Create the window on first use, refresh the project note, and
 * present it. Do nothing while commands are blocked.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.showPreferences() {
    if (commandsBlocked()) {
        return
    }
    if (preferencesWindow == null) {
        createPreferences()
    }
    refreshProjectNote()
    preferencesWindow.present()
}

/*
 * Refresh the project-override note in preferences.
 *
 * Purpose: Show the active project's override summary, or clear it. Update
 * the Project button and the settings-path label.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.refreshProjectNote() {
    if (projectNote == null) {
        return
    }
    String overrides = ""
    if (activeProject != null) {
        overrides = activeProject.overrideSummary()
    }

    if (overrides.equals("")) {
        projectNote.setText("")
    }
        else {
        projectNote.setText(format(
                "Project {} overrides: {}",
                activeProject.name,
                overrides))
    }

    if (configureProjectButton != null) {
        configureProjectButton.setSensitive(activeProject != null
                && !commandsBlocked())
    }
    refreshSettingsPathLabel()
}

/*
 * Refresh the label that names the settings file.
 *
 * Purpose: Set the label to the path settings are saved to.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.refreshSettingsPathLabel() {
    if (settingsPathLabel == null) {
        return
    }
    settingsPathLabel.setText(
            format(
            "Automatically saved to {}",
            settings.path))
}

/*
 * Return the directory used as the settings root.
 *
 * Purpose: Use the active project root, or the working directory when no
 * project is open.
 *
 * Parameters:
 *   none.
 *
 * Returns: that directory path.
 */

String Cedit.settingsRoot() {
    if (activeProject != null) {
        return(activeProject.root)
    }
    return(System.FileSystem().getCwd())
}

/*
 * Build the startup section stored in global settings.
 *
 * Purpose: Format reopen_last and last_root as a TOML patch.
 *
 * Parameters:
 *   none.
 *
 * Returns: the startup TOML text.
 */

String Cedit.startupPatch() {
    return(format("version = 1\n[project]\nreopen_last = {}\nlast_root = {}\n",
            settings.reopenLast, Gtk.Config().quote(
            settings.lastRoot)))
}

/*
 * Choose the base text for a global settings rewrite.
 *
 * Purpose: Keep valid TOML unchanged. From invalid text, keep a quoted
 * sdk_prefix, or use a version header.
 *
 * Parameters:
 *   disk — raw text of the global settings file.
 *
 * Returns: the merge base, or empty when disk is empty.
 */

String Cedit.globalSettingsBase(String disk) {
    if (disk.equals("")) {
        return("")
    }
    if (Gtk.Config().validate(disk).equals("")) {
        return(disk)
    }
        // Preserve sdk_prefix from a corrupt shared settings file when
        // repairing.
        // Config.value cannot parse invalid TOML, so scan the raw text.

    list lines = disk.split("\n")
    int64 index = 0
    while (index < lines.length) {

        String trimmed = (lines[index] as String).trim()
        if (trimmed.startsWith("sdk_prefix") || trimmed.startsWith(
                "\"sdk_prefix\"")) {
            list fields = trimmed.split("=")
            if (fields.length >= 2) {
                String raw = (fields[1] as String).trim()
                if (raw.startsWith("\"") && raw.endsWith("\"")
                        && raw.length >= 2) {
                    return(format("version = 1\nsdk_prefix = {}\n", raw))
                }
            }
        }

        index = index + 1
    }

    return("version = 1\n")
}

/*
 * Recover startup keys from a malformed settings file.
 *
 * Purpose: Read reopen_last and last_root from raw text when the file is
 * not valid TOML. Valid or empty text is left alone.
 *
 * Parameters:
 *   disk — raw settings text to scan.
 *
 * Returns: nothing.
 */

void Cedit.recoverStartupFrom(String disk) {
    if (disk.equals("") || Gtk.Config().validate(disk).equals("")) {
        return
    }

    list lines = disk.split("\n")
    int64 index = 0
    while (index < lines.length) {

        String trimmed = (lines[index] as String).trim()
        if (trimmed.startsWith("reopen_last") || trimmed.startsWith(
                "\"reopen_last\"")) {
            list fields = trimmed.split("=")
            if (fields.length >= 2) {
                String raw = (fields[1] as String).trim()
                if (raw.equals("true")) {
                    settings.reopenLast = true
                }
                if (raw.equals("false")) {
                    settings.reopenLast = false
                }
            }
        }

        if (trimmed.startsWith("last_root") || trimmed.startsWith(
                "\"last_root\"")) {
            list fields = trimmed.split("=")
            if (fields.length >= 2) {
                String raw = (fields[1] as String).trim()
                if (raw.startsWith("\"") && raw.endsWith("\"")
                        && raw.length >= 3) {
                    String path = raw[1..(raw.length - 2)]
                    if (path.startsWith("/")) {
                        settings.lastRoot = path
                    }
                }
            }
        }

        index = index + 1
    }

}

/*
 * Create or repair the global settings file.
 *
 * Purpose: Leave valid, binary, and unrelated invalid files alone. Rewrite
 * a malformed file that has startup keys, or create the global
 * file when it is the active path and settings loaded cleanly.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.ensureGlobalSettingsFile() {

    String disk = readSettingsDisk(settings.globalPath)
    if (System.FileSystem().isFile(settings.globalPath)) {
            // Config.validate fatals on embedded NUL; leave binary/corrupt
            // files alone
            // unless startup keys are present to recover.
        if (!GtkSource.Content().isText(disk)) {
            return
        }
        if (Gtk.Config().validate(disk).equals("")) {
            return
        }
            // Only rewrite a malformed global file when startup keys are
            // present in
            // the raw text. Other invalid files must keep failing load so
            // Preferences
            // can show the error and refuse to clobber them.
        if (!disk.contains("reopen_last") && !disk.contains("last_root")) {
            return
        }
        bool reopen = settings.reopenLast
        String lastRoot = settings.lastRoot
        settings.reopenLast = false
        settings.lastRoot = ""
        recoverStartupFrom(disk)
        if (!settings.reopenLast && settings.lastRoot.equals("")) {
            settings.reopenLast = reopen
            settings.lastRoot = lastRoot
            return
        }
        String text = Gtk.Config().merge(globalSettingsBase(disk), startupPatch(
                ))
        if (!writeSettingsFile(settings.globalPath, text)) {
            settings.reopenLast = reopen
            settings.lastRoot = lastRoot
            return
        }
        if (settings.path.equals(settings.globalPath)) {
            settings.errors = ""
            settings.writable = true
            settings.resetEditor()
            settings.resetKeyboard()
            settings.load()
            persistedText = settings.original
        }
        return
    }

    if (!settings.path.equals(settings.globalPath)) {
        return
    }
    if (!settings.errors.equals("")) {
        return
    }
    String text = settings.serialize()
    if (!writeSettingsFile(settings.globalPath, text)) {
        return
    }
    settings.original = text
    persistedText = text
}

/*
 * Write settings text to a path.
 *
 * Purpose: Create the parent directory, write the full text, and flush.
 * Any I/O error fails the write.
 *
 * Parameters:
 *   path — destination file path.
 *   text — full file contents.
 *
 * Returns: true when the file is written and flushed.
 */

bool Cedit.writeSettingsFile(String path, String text) {
    String directory = System.FileSystem().dirname(path)
    if (!makeSettingsDirectory(directory)) {
        return(false)
    }
    System.File output = null
    try {
        output = System.File(path, "w")
    }
        except(Exception) {
        return(false)
    }
    int64 written = output.write(text)
    String writeError = System.System().lastError()
    if (written != text.length) {
        output.close()
        return(false)
    }
    output.flush()
    String flushError = System.System().lastError()
    output.close()
    String closeError = System.System().lastError()
    if (!writeError.equals("") || !flushError.equals("") || !closeError.equals(
            "")) {
        return(false)
    }
    return(true)
}

/*
 * Write startup keys into the global settings file.
 *
 * Purpose: Merge the startup patch onto the existing file, or write the
 * patch alone when there is no base text.
 *
 * Parameters:
 *   none.
 *
 * Returns: true when the global file is written.
 */

bool Cedit.writeStartupToGlobal() {
    String disk = readSettingsDisk(settings.globalPath)
    String base = globalSettingsBase(disk)
    if (base.equals("")) {
        return(writeSettingsFile(settings.globalPath, startupPatch()))
    }
    return(writeSettingsFile(settings.globalPath,
            Gtk.Config().merge(base, startupPatch())))
}

/*
 * Copy global editor settings into a new local file.
 *
 * Purpose: Remove reopen_last and last_root. Text without those keys is
 * returned unchanged, and invalid input yields empty.
 *
 * Parameters:
 *   globalText — raw global settings text.
 *
 * Returns: local seed text, or empty when global text cannot be used.
 */

String Cedit.seedLocalSettings(String globalText) {
        // Editor/keyboard only: startup reopen keys stay in the global file.
    if (globalText.equals("") || !GtkSource.Content().isText(globalText) ||
            !Gtk.Config().validate(
            globalText).equals(
            "")) {
        return("")
    }
        // Config.remove rewrites/normalizes the document; skip when nothing to
        // strip
        // so SDK-only and minimal templates stay byte-identical.
    if (!globalText.contains("reopen_last") && !globalText.contains(
            "last_root")) {
        return(globalText)
    }
    String seed = Gtk.Config().remove(globalText, "project", "reopen_last")
    seed = Gtk.Config().remove(seed, "project", "last_root")
    return(seed)
}

/*
 * Mirror editor settings into the global file.
 *
 * Purpose: Merge editor and keyboard text onto the global file while
 * keeping the startup keys.
 *
 * Parameters:
 *   editorText — serialized editor and keyboard settings.
 *
 * Returns: true when the global file is written.
 */

bool Cedit.writeMirroredGlobal(String editorText) {
        // Keep reopen_last/last_root when mirroring editor/keyboard into the
        // global file.
    String disk = readSettingsDisk(settings.globalPath)
    String base = globalSettingsBase(disk)
    String merged = editorText
    if (!base.equals("")) {
        merged = Gtk.Config().merge(base, editorText)
    }
    return(writeSettingsFile(settings.globalPath,
            Gtk.Config().merge(merged, startupPatch())))
}

/*
 * Switch settings to a project-local file.
 *
 * Purpose: Seed a missing local file from global settings, then load it.
 * Keep startup keys on the in-memory settings.
 *
 * Parameters:
 *   root — project directory whose local settings to use.
 *
 * Returns: nothing.
 */

void Cedit.adoptSettingsRoot(String root) {
    if (root.equals("")) {
        return
    }

    String local = settings.localPath(root)
    bool reopen = settings.reopenLast
    String lastRoot = settings.lastRoot
    if (!System.FileSystem().isFile(local)) {
        ensureGlobalSettingsFile()
        String seed = seedLocalSettings(readSettingsDisk(settings.globalPath))
            // Only invent a template when the global file is truly missing, not
            // unreadable.
        if (seed.equals("") && settings.path.equals(settings.globalPath) &&
                settings.errors.equals("") && !System.FileSystem().isFile(
                settings.globalPath)) {
            String previous = settings.path
            settings.path = settings.globalPath
            seed = seedLocalSettings(settings.serialize())
            settings.path = previous
        }
        if (!seed.equals("")) {
            writeSettingsFile(local, seed)
        }
    }

    if (!System.FileSystem().isFile(local)) {
        return
    }
    if (settings.path.equals(local)) {
        return
    }
    settings.path = local
    settings.errors = ""
    settings.writable = true
    settings.resetEditor()
    settings.resetKeyboard()
    settings.load()
    settings.reopenLast = reopen
    settings.lastRoot = lastRoot
    persistedText = settings.original
    reapplyDocumentSettings()
    syncViewMenu()
    refreshSettingsPathLabel()
}

/*
 * Apply the reopen-last-project checkbox.
 *
 * Purpose: Store the checkbox and the active project root, then write
 * startup keys. A failed write is reported.
 *
 * Parameters:
 *   active — true when the checkbox is on.
 *
 * Returns: nothing.
 */

void Cedit.reopenChanged(bool active) {
    if (refreshingPreferences) {
        return
    }
    settings.reopenLast = active
    settings.lastRoot = ""
    if (active && activeProject != null) {
        settings.lastRoot = activeProject.root
    }
        // Startup keys are global-only; local serialize ignores them, so skip
        // settingsChanged and write the global file directly.
    if (!writeStartupToGlobal()) {
        settingsSaveFailure(format("could not update {}", settings.globalPath))
        return
    }
    if (preferencesMessage != null) {
        preferencesMessage.setText("Settings saved")
    }
}

/*
 * Save the current settings.
 *
 * Purpose: Ensure the preferences window exists, then run the normal
 * settings-changed save.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.persistSettings() {
    if (preferencesWindow == null) {
        createPreferences()
    }
    settingsChanged()
}

/*
 * Remember a project root for the next startup.
 *
 * Purpose: When reopen-last is on, store root as last_root and write the
 * global startup keys.
 *
 * Parameters:
 *   root — project directory to remember.
 *
 * Returns: nothing.
 */

void Cedit.rememberProject(String root) {
    if (settings.reopenLast && !settings.lastRoot.equals(root)) {
        settings.lastRoot = root
        writeStartupToGlobal()
    }
}

/*
 * Drop a project root from startup memory.
 *
 * Purpose: Clear last_root when it matches root, then write the global
 * startup keys.
 *
 * Parameters:
 *   root — project directory to forget.
 *
 * Returns: nothing.
 */

void Cedit.forgetProject(String root) {
    if (settings.lastRoot.equals(root)) {
        settings.lastRoot = ""
        writeStartupToGlobal()
    }
}
