/*
 * src/ceditConfirmPreferencesReset.cw - Preferences reset, view toggles,
 * settings save.
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
 * Cedit.confirmPreferencesReset
 *
 * Purpose: Apply an Editor or Keyboard preferences reset when that
 * section was requested, refresh its controls, then dismiss the
 * prompt and save.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.confirmPreferencesReset() {

    if (resetSection.equals("Editor")) {
        settings.resetEditor()
        refreshingPreferences = true
        fontEntry.setText(settings.fontFamily)
        sizeEntry.setText(format("{}", settings.fontSize))
        tabsEntry.setText(format("{}", settings.tabWidth))
        if (marginEntry != null) {
            marginEntry.setText(format("{}", settings.rightMargin))
        }
        spacesCheck.setActive(settings.insertSpaces)
        numbersCheck.setActive(settings.lineNumbers)
        wrapCheck.setActive(settings.wrap)
        highlightCheck.setActive(settings.highlightLine)
        saveTabCheck.setActive(settings.saveOnTabLoss)
        saveWindowCheck.setActive(settings.saveOnWindowLoss)
        stripCheck.setActive(settings.stripTrailingSpaces)
        bracketsCheck.setActive(settings.autoCompleteBrackets)
        if (autoIndentCheck != null) {
            autoIndentCheck.setActive(settings.autoIndent)
        }
        if (unsavedMarksCheck != null) {
            unsavedMarksCheck.setActive(settings.showUnsavedMarks)
        }
        refreshingPreferences = false
    }

    if (resetSection.equals("Keyboard")) {
        settings.resetKeyboard()
        settings.shortcutRevision = settings.shortcutRevision + 1
        int64 i = 0
        while (i < keyboardRows.length) {
            (keyboardRows[i] as KeyboardPreference).refresh()
            i = i + 1
        }
    }
    cancelPreferencesReset()
    settingsChanged()
}

/*
 * Cedit.settingsChanged
 *
 * Purpose: Apply current settings to open documents and the view, then
 * persist them. A save already in flight is queued; unwritable
 * settings stay session-only.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.settingsChanged() {
    int64 i = 0
    while (i < documents.length) {
        applyDocumentSettings(documents[i] as EditorDocument)
        i = i + 1
    }
    applyProjectManagerVisibility()
    syncViewMenu()

    if (!settings.writable) {
        String message = diagnostic("CEDIT2001", format(
                "{}: {}; changes apply for this session only and saving is disabled.",
                settings.path, settings.errors))
        if (preferencesMessage != null) {
            preferencesMessage.setText(message)
        }
            else {
            status.setText(message)
        }
        return
    }

    if (savePending) {
        saveAgain = true
        return
    }
    saveSettings()
}

/*
 * Cedit.effectiveLineNumbers
 *
 * Purpose: Return whether line numbers are shown, preferring the active
 * project's override when it has one.
 *
 * Parameters:
 *   none.
 *
 * Returns: true when line numbers are shown.
 */

bool Cedit.effectiveLineNumbers() {
    if (activeProject != null && activeProject.hasNumbers) {
        return(activeProject.lineNumbers)
    }
    return(settings.lineNumbers)
}

/*
 * Cedit.publishLineNumbers
 *
 * Purpose: Store the line-number choice, and copy it onto the active
 * project when that project overrides numbers. Save the project when it
 * is writable and no save is running, and refresh the checkbox.
 *
 * Parameters:
 *   active — whether line numbers should be shown.
 *
 * Returns: nothing.
 */

void Cedit.publishLineNumbers(bool active) {
    settings.lineNumbers = active
    if (activeProject != null && activeProject.hasNumbers) {
        activeProject.lineNumbers = active
        if (activeProject.writable && projectSaves == 0 && projectOp.equals(
                "")) {
            writeProject(activeProject, true, false, "configure")
        }
    }
    if (numbersCheck != null) {
        refreshingPreferences = true
        numbersCheck.setActive(active)
        refreshingPreferences = false
    }
}

/*
 * Cedit.lineNumbersChecked
 *
 * Purpose: Apply a line-number checkbox change unless the view menu is
 * being synchronized from the current settings.
 *
 * Parameters:
 *   active — new checkbox state.
 *
 * Returns: nothing.
 */

void Cedit.lineNumbersChecked(bool active) {
    if (syncingView) {
        return
    }
    publishLineNumbers(active)
    settingsChanged()
}

/*
 * Cedit.toggleLineNumbers
 *
 * Purpose: Flip whether line numbers are shown and save that choice.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.toggleLineNumbers() {
    lineNumbersChecked(!effectiveLineNumbers())
}

/*
 * Cedit.whitespaceChecked
 *
 * Purpose: Apply a show-whitespace checkbox change unless the view menu
 * is being synchronized from the current settings.
 *
 * Parameters:
 *   active — whether whitespace should be shown.
 *
 * Returns: nothing.
 */

void Cedit.whitespaceChecked(bool active) {
    if (syncingView) {
        return
    }
    settings.showWhitespace = active
    settingsChanged()
}

/*
 * Cedit.toggleWhitespace
 *
 * Purpose: Flip whether whitespace is shown and save that choice.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.toggleWhitespace() {
    whitespaceChecked(!settings.showWhitespace)
}

/*
 * Cedit.lineEndsChecked
 *
 * Purpose: Apply a show-line-ends checkbox change unless the view menu
 * is being synchronized from the current settings.
 *
 * Parameters:
 *   active — whether line-end marks should be shown.
 *
 * Returns: nothing.
 */

void Cedit.lineEndsChecked(bool active) {
    if (syncingView) {
        return
    }
    settings.showLineEnds = active
    settingsChanged()
}

/*
 * Cedit.toggleLineEnds
 *
 * Purpose: Flip whether line-end marks are shown and save that choice.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.toggleLineEnds() {
    lineEndsChecked(!settings.showLineEnds)
}

/*
 * Cedit.indentMarkersChecked
 *
 * Purpose: Apply a show-indent-markers checkbox change unless the view
 * menu is being synchronized from the current settings.
 *
 * Parameters:
 *   active — whether indent markers should be shown.
 *
 * Returns: nothing.
 */

void Cedit.indentMarkersChecked(bool active) {
    if (syncingView) {
        return
    }
    settings.showIndentMarkers = active
    settingsChanged()
}

/*
 * Cedit.toggleIndentMarkers
 *
 * Purpose: Flip whether indent markers are shown and save that choice.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.toggleIndentMarkers() {
    indentMarkersChecked(!settings.showIndentMarkers)
}

/*
 * Cedit.projectManagerChecked
 *
 * Purpose: Apply a project-manager checkbox change unless the view menu
 * is being synchronized from the current settings.
 *
 * Parameters:
 *   active — whether the project manager should be shown.
 *
 * Returns: nothing.
 */

void Cedit.projectManagerChecked(bool active) {
    if (syncingView) {
        return
    }
    settings.showProjectManager = active
    settingsChanged()
}

/*
 * Cedit.toggleProjectManager
 *
 * Purpose: Flip whether the project manager is shown and save that choice.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.toggleProjectManager() {
    projectManagerChecked(!settings.showProjectManager)
}

/*
 * Cedit.closeSidePanel
 *
 * Purpose: Hide the project manager side panel and save that choice.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.closeSidePanel() {
    projectManagerChecked(false)
}

/*
 * Cedit.scheduleLanguagePoll
 *
 * Purpose: Queue a language-client poll in 100 ms while the client is
 * running.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.scheduleLanguagePoll() {
    if (client == null || !client.running) {
        return
    }
    Gtk.Application().schedule(100, languagePollAction)
}

/*
 * Cedit.languagePoll
 *
 * Purpose: Poll the language client once when one is attached.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.languagePoll() {
    if (client != null) {
        client.poll()
    }
}

/*
 * Cedit.languageFlush
 *
 * Purpose: Send the current document to the running language client when
 * its latest edit has not been sent.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.languageFlush() {
    if (client == null || !client.running) {
        return
    }
    if (client.generation == client.sentGeneration) {
        return
    }
    client.sendChange(currentDocument())
}

/*
 * Cedit.scheduleDiskPoll
 *
 * Purpose: Queue a disk-change check in 2 seconds while the window is
 * open.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.scheduleDiskPoll() {
    if (!presented || window == null || window.disposed()) {
        return
    }
    Gtk.Application().schedule(2000, diskPollAction)
}

/*
 * Cedit.diskPoll
 *
 * Purpose: Check open documents for changes on disk, then queue the next
 * check.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.diskPoll() {
    if (!presented || window == null || window.disposed()) {
        return
    }
    checkDiskChange()
    scheduleDiskPoll()
}

/*
 * Cedit.openRecentPath
 *
 * Purpose: Open a recent file unless commands are blocked.
 *
 * Parameters:
 *   path — filesystem path of the file to open.
 *
 * Returns: nothing.
 */

void Cedit.openRecentPath(String path) {
    if (commandsBlocked()) {
        return
    }
    openFile(path)
}

/*
 * Cedit.syncViewMenu
 *
 * Purpose: Match View menu checks to the effective line-number,
 * whitespace, line-end, indent-marker, and project-manager
 * settings.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.syncViewMenu() {
    if (menu == null) {
        return
    }
    syncingView = true
    menu.setItemChecked(lineNumbersItem, effectiveLineNumbers())
    menu.setItemChecked(whitespaceItem, settings.showWhitespace)
    menu.setItemChecked(lineEndsItem, settings.showLineEnds)
    menu.setItemChecked(indentMarkersItem, settings.showIndentMarkers)
    menu.setItemChecked(projectManagerItem, settings.showProjectManager)
    syncingView = false
}

/*
 * Cedit.applyProjectManagerVisibility
 *
 * Purpose: Show or hide the project manager, remembering the splitter
 * width while it is hidden and restoring that width when shown.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.applyProjectManagerVisibility() {
    if (workspace == null || project == null) {
        return
    }
    if (!settings.showProjectManager) {
        int64 width = workspace.position()
        if (width > 0) {
            projectManagerWidth = width
        }
    }
    if (sidePanel != null) {
        sidePanel.setVisible(settings.showProjectManager)
    }
    project.sidebar.setVisible(settings.showProjectManager)
    if (settings.showProjectManager && projectManagerWidth > 0) {
        workspace.setPosition(projectManagerWidth)
    }
}

/*
 * Cedit.keyboardSettingsChanged
 *
 * Purpose: Bump the shortcut revision and persist the keyboard settings.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.keyboardSettingsChanged() {
    settings.shortcutRevision = settings.shortcutRevision + 1
    settingsChanged()
}

/*
 * Cedit.saveSettings
 *
 * Purpose: Write settings when they differ from the last save, refusing
 * when the on-disk file is missing, changed, or unusable.
 *
 * Parameters:
 *   none.
 *
 * Returns: true when no write was needed or a save started; else false.
 */

bool Cedit.saveSettings() {
    String text = settings.serialize()
    if (text.equals(persistedText)) {
        return(true)
    }
    String directory = System.FileSystem().dirname(settings.path)
    if (!makeSettingsDirectory(directory)) {
        settingsSaveFailure(System.System().lastError())
        return(false)
    }
        // Refuse to overwrite a file edited externally since the last
        // load/save.

    if (System.FileSystem().exists(settings.path)) {
        if (!System.FileSystem().isFile(settings.path) ||
                System.FileSystem().fileSize(
                settings.path) > 65536) {
            settingsSaveFailure(
                    "current settings must be a regular file no larger than 64 KiB")
            return(false)
        }
        System.File file = null
        try {
            file = System.File(settings.path, "r")
        }
        except(Exception) {
            settingsSaveFailure("cannot read current settings")
            return(false)
        }
        String disk = ""
        try {
            disk = file.readAll()
        }
            except(Exception) as failure {
            file.close()
            settingsSaveFailure(failure.message)
            return(false)
        }
        String readError = System.System().lastError()
        file.close()
        if (!readError.equals("") || !disk.equals(persistedText)) {
            settingsSaveFailure(
                    "settings changed on disk; restart before saving preferences")
            return(false)
        }
    }
    else {
        if (!persistedText.equals("")) {
            settingsSaveFailure(
                    "settings removed on disk; restart before saving preferences")
            return(false)
        }
    }

    savingText = text
    savePending = true
    if (preferencesMessage != null) {
        preferencesMessage.setText("Saving settings...")
    }
    Gtk.Config().save(settings.path, text, persistedText, _self().settingsSaved)
    return(true)
}

/*
 * Cedit.makeSettingsDirectory
 *
 * Purpose: Create a settings directory, including any missing parents.
 *
 * Parameters:
 *   directory — path of the directory to create.
 *
 * Returns: true when the directory exists or was created.
 */

bool Cedit.makeSettingsDirectory(String directory) {
    if (System.FileSystem().isDir(directory)) {
        return(true)
    }
    String parent = System.FileSystem().dirname(directory)
    if (parent.equals(directory) || directory.equals("")) {
        return(false)
    }
    if (!makeSettingsDirectory(parent)) {
        return(false)
    }
    return(System.FileSystem().mkdir(directory))
}

/*
 * Cedit.diagnostic
 *
 * Purpose: Format a diagnostic as "cedit: error[code]: explanation".
 *
 * Parameters:
 *   code — diagnostic identifier, such as CEDIT2001.
 *   explanation — human-readable detail appended after the code.
 *
 * Returns: the formatted diagnostic text.
 */

String Cedit.diagnostic(String code, String explanation) {
    return(format("cedit: error[{}]: {}", code, explanation))
}

/*
 * Cedit.reportDiagnostic
 *
 * Purpose: Show a formatted diagnostic in the status bar.
 *
 * Parameters:
 *   code — diagnostic identifier, such as CEDIT2001.
 *   explanation — human-readable detail.
 *
 * Returns: nothing.
 */

void Cedit.reportDiagnostic(String code, String explanation) {
    status.setText(diagnostic(code, explanation))
}

/*
 * Cedit.settingsSaveFailure
 *
 * Purpose: Report a settings-save failure in the preferences message or
 * the status bar, and leave the changes session-only.
 *
 * Parameters:
 *   detail — why the save failed.
 *
 * Returns: nothing.
 */

void Cedit.settingsSaveFailure(String detail) {
    String message = diagnostic("CEDIT2001", format(
            "Settings save failed: {} at {}; changes remain session-only. Check the settings path and permissions, then retry.",
            detail, settings.path))
    if (preferencesMessage != null) {
        preferencesMessage.setText(message)
    }
        else {
        status.setText(message)
    }
}

/*
 * Cedit.settingsSaved
 *
 * Purpose: Finish a settings save by recording success or showing the
 * error. A queued resave or window close runs only after success.
 *
 * Parameters:
 *   error — empty on success; otherwise the failure text.
 *
 * Returns: nothing.
 */

void Cedit.settingsSaved(String error) {
    savePending = false
    if (!error.equals("")) {
        settingsSaveFailure(error)
        saveAgain = false
        closeAfterSave = false
        if (preferencesWindow != null && !preferencesWindow.disposed()) {
            preferencesWindow.present()
        }
        return
    }
    persistedText = savingText
    settings.original = savingText
    if (preferencesMessage != null) {
        preferencesMessage.setText("Settings saved")
    }
    if (saveAgain) {
        saveAgain = false
        if (!saveSettings()) {
            closeAfterSave = false
            preferencesWindow.present()
            return
        }
    }
    if (closeAfterSave && !savePending && projectSaves == 0 && !window.disposed(
            )) {
        closeAfterSave = false
        window.close()
    }
}

/*
 * Cedit.version
 *
 * Purpose: Return the editor version string.
 *
 * Parameters:
 *   none.
 *
 * Returns: the version, kept in step with the CMake project version.
 */

String Cedit.version() {
        // Keep in sync with project(cedit VERSION ...) in CMakeLists.txt.
    return("0.0.1")
}

/*
 * Cedit.projectFailure
 *
 * Purpose: Report a project failure in the status bar and an alert, with
 * a short hint to correct the issue and retry.
 *
 * Parameters:
 *   title — short heading shown for the failure.
 *   detail — what went wrong.
 *
 * Returns: nothing.
 */

void Cedit.projectFailure(String title, String detail) {
    String recovery = "Review the path and details, correct the issue, then retry."
    String message = diagnostic("CEDIT2002", format("{}: {}", title, detail))
    reportDiagnostic("CEDIT2002", format("{}: {}; {}", title, detail, recovery))
    Gtk.AlertDialog().show(window, title, format("{}\n\n{}", message, recovery))
}

/*
 * Cedit.canonicalFolder
 *
 * Purpose: Resolve a local path to a canonical directory. A remote path
 * or a path that is not an accessible folder is rejected.
 *
 * Parameters:
 *   path — folder path to resolve.
 *   title — heading used when the path is rejected.
 *
 * Returns: the canonical directory, or empty when the path is rejected.
 */

String Cedit.canonicalFolder(String path, String title) {
    if (path.contains("://")) {
        projectFailure(title, "only local filesystem paths are supported")
        return("")
    }
    String requested = path
    if (!requested.startsWith("/")) {
        requested = System.FileSystem().join(System.FileSystem().getCwd(),
                requested)
    }
    String canonical = System.FileSystem().absolutePath(requested)
    if (canonical.equals("") || !System.FileSystem().isDir(canonical)) {
        projectFailure(title, format("{} is not an accessible folder", path))
        return("")
    }
    return(canonical)
}

/*
 * Cedit.loadProject
 *
 * Purpose: Load a project from a folder. A .cwhip folder that holds
 * project metadata is loaded from its parent.
 *
 * Parameters:
 *   path — folder or metadata directory to open.
 *   title — heading used when the folder or project cannot load.
 *
 * Returns: the loaded project, or null when loading fails.
 */

CwhipProject Cedit.loadProject(String path, String title) {
    String root = canonicalFolder(path, title)
    if (root.equals("")) {
        return(null)
    }
        // Choosing a metadata folder itself selects its project root.
    if (System.FileSystem().basename(root).equals(".cwhip") &&
            System.FileSystem().isFile(System.FileSystem().join(
            root,
            "project.toml"))) {
        root = System.FileSystem().dirname(root)
    }
    CwhipProject candidate = CwhipProject(root)
    String problem = candidate.load(settings)
    if (!problem.equals("")) {
        projectFailure(title, problem)
        return(null)
    }
    return(candidate)
}

/*
 * Cedit.openRootArgument
 *
 * Purpose: Open a startup folder as a project when it has metadata, or
 * as a plain folder. Ignore the path when a root is already set.
 *
 * Parameters:
 *   path — folder path from the command line.
 *
 * Returns: nothing.
 */

void Cedit.openRootArgument(String path) {
    if (activeProject != null || !project.rootPath.equals("")) {
        status.setText(format("Ignored extra folder argument: {}", path))
        return
    }
    String root = canonicalFolder(path, "Could not open folder")
    if (root.equals("")) {
        return
    }

    if (System.FileSystem().isFile(System.FileSystem().join(
            root,
            ".cwhip/project.toml"))) {
        CwhipProject candidate = loadProject(root, "Could not open project")
        if (candidate != null) {
            activateProject(candidate, true)
        }
        return
    }

    project.setRoot(root)
    adoptSettingsRoot(root)
    noteOpenFiles()
}

/*
 * Cedit.chooseProjectFolder
 *
 * Purpose: Open a folder chooser to create, open, or save a project.
 *
 * Parameters:
 *   purpose — "project-new", "project-open", or "project-save-as".
 *
 * Returns: nothing.
 */

void Cedit.chooseProjectFolder(String purpose) {
    if (commandsBlocked()) {
        return
    }
    chooserPurpose = purpose
    String initialPath = project.rootPath
    if (purpose.equals("project-save-as") && activeProject != null) {
        initialPath = System.FileSystem().dirname(activeProject.root)
    }
    fileDialog = Gtk.FileDialog(window, initialPath, _self(
            ).projectFolderChosen)
    updateMenu()
}

/*
 * Cedit.newProject
 *
 * Purpose: Ask for a folder in which to create a project.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.newProject() {
    chooseProjectFolder("project-new")
}

/*
 * Cedit.openProject
 *
 * Purpose: Ask for a folder and open the project there.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.openProject() {
    chooseProjectFolder("project-open")
}

/*
 * Cedit.saveProjectAs
 *
 * Purpose: If a project is open, ask for a folder in which to save a
 * copy of it.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.saveProjectAs() {
    if (activeProject == null) {
        status.setText("No project is open")
        return
    }
    chooseProjectFolder("project-save-as")
}

/*
 * Cedit.projectFolderChosen
 *
 * Purpose: Open, create, or save-as a project from the chosen folder, or
 * report that the chooser was cancelled.
 *
 * Parameters:
 *   path — chosen folder, or empty when the chooser was cancelled.
 *
 * Returns: nothing.
 */

void Cedit.projectFolderChosen(String path) {
    fileDialog = null
    String purpose = chooserPurpose
    chooserPurpose = ""
    updateMenu()
    if (purpose.equals("")) {
        return
    }
    if (path.equals("")) {
        status.setText("Cancelled")
        return
    }
    if (purpose.equals("project-open")) {
        openProjectAt(path)
    }
    if (purpose.equals("project-new")) {
        prepareNewProject(path, false)
    }
    if (purpose.equals("project-save-as")) {
        prepareNewProject(path, true)
    }
}

