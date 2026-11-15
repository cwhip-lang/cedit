/*
 * src/ceditOpenProjectAt.cw - Open/switch/save/delete project operations.
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
 * Cedit.openProjectAt
 *
 * Purpose: When a project loads, start switching to it unless that same
 * project is already open.
 *
 * Parameters:
 *   path — folder that holds the project.
 *
 * Returns: nothing.
 */

void Cedit.openProjectAt(String path) {
    CwhipProject candidate = loadProject(path, "Could not open project")
    if (candidate == null) {
        return
    }
    if (activeProject != null && activeProject.root.equals(candidate.root)) {
        status.setText(format("Project already open: {}", candidate.root))
        return
    }
    nextProject = candidate
    beginSwitch("open")
}

/*
 * Cedit.prepareNewProject
 *
 * Purpose: Prepare a new project or a Save As in a folder, and ask before
 * replacing metadata that is already there.
 *
 * Parameters:
 *   path — destination folder.
 *   copy — true to copy the open project's configuration and workspace.
 *
 * Returns: nothing.
 */

void Cedit.prepareNewProject(String path, bool copy) {
    String title = "Could not create project"
    if (copy) {
        title = "Could not save project as"
    }
    String root = canonicalFolder(path, title)
    if (root.equals("")) {
        return
    }
    if (copy && (activeProject == null || activeProject.root.equals(root))) {
        projectFailure(
                title,
                "Choose a different folder from the current project root")
        return
    }
    CwhipProject candidate = CwhipProject(root)
    String problem = candidate.metadataProblem()
    if (!problem.equals("")) {
        projectFailure(title, problem)
        return
    }
        // Existing on-disk text becomes the expected original, guarding
        // replacement.
    candidate.original = candidate.readMetadata(candidate.configPath, 65536)
    bool exists = !candidate.readMissing
    if (!candidate.readError.equals("") && !candidate.readContent) {
        projectFailure(title, candidate.readError)
        return
    }
    candidate.workspaceOriginal = candidate.readMetadata(
            candidate.workspacePath, 1048576)
    exists = exists || !candidate.readMissing
    if (!candidate.readError.equals("") && !candidate.readContent) {
        projectFailure(title, candidate.readError)
        return
    }
    if (copy) {
        candidate.copyConfiguration(activeProject)
        candidate.workspaceText = captureWorkspace(activeProject.root, root)
    }
    else {
        candidate.workspaceText = captureWorkspace(root, root)
    }
    nextProject = candidate
    String op = "new"
    if (copy) {
        op = "save-as"
    }

    if (exists) {
        askConfirm(format("replace-{}", op), format(
                "{} already has Cwhip project metadata. Replace {} and {}?",
                root,
                candidate.configPath,
                candidate.workspacePath), "Replace Metadata")
        return
    }

    startNewProject(op)
}

/*
 * Cedit.startNewProject
 *
 * Purpose: Start the prepared project. Save As writes the new metadata
 * and leaves the original project's files untouched.
 *
 * Parameters:
 *   op — "new" or "save-as".
 *
 * Returns: nothing.
 */

void Cedit.startNewProject(String op) {
        // Save As leaves the original project's files untouched.
    if (op.equals("save-as")) {
        writeProject(nextProject, true, true, "activate")
        return
    }
    beginSwitch("new")
}

/*
 * Cedit.saveProject
 *
 * Purpose: Capture the open project's workspace and write its metadata.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.saveProject() {
    if (commandsBlocked() || activeProject == null) {
        return
    }
    activeProject.workspaceText = captureWorkspace(activeProject.root,
            activeProject.root)
    status.setText("Saving project...")
    writeProject(activeProject, true, true, "save")
}

/*
 * Cedit.deleteProject
 *
 * Purpose: Ask whether to delete only the open project's metadata files.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.deleteProject() {
    if (commandsBlocked() || activeProject == null) {
        return
    }
    askConfirm("delete", format(
            "Delete Cwhip project metadata for {}? Only {} and {} are removed; source files are kept.",
            activeProject.root,
            activeProject.configPath,
            activeProject.workspacePath), "Delete Metadata")
}

/*
 * Cedit.deleteProjectMetadata
 *
 * Purpose: Delete the open project's metadata files, then keep the folder
 * open without a project.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.deleteProjectMetadata() {
    CwhipProject target = activeProject
    if (target == null) {
        return
    }
    String problem = target.metadataProblem()
    if (!problem.equals("")) {
        projectFailure("Could not delete project metadata", problem)
        return
    }
    String failures = ""
    if (System.FileSystem().exists(target.workspacePath)) {
        if (System.FileSystem().remove(target.workspacePath)) {
            target.workspaceOriginal = ""
        }
            else {
            failures.append(format("{}: {}\n", target.workspacePath,
                    System.System().lastError()))
        }
    }
    if (System.FileSystem().exists(target.configPath) && !System.FileSystem(
            ).remove(
            target.configPath)) {
        failures.append(format("{}: {}\n", target.configPath, System.System(
                ).lastError()))
    }
    if (!failures.equals("")) {
        projectFailure("Could not delete project metadata", failures)
        return
    }
        // Succeeds only if the metadata directory is now empty; unknown files
        // are preserved.
    System.FileSystem().rmdir(target.directory)
    detachProject()
    project.setRoot(target.root)
    adoptSettingsRoot(target.root)
    noteOpenFiles()
    forgetProject(target.root)
    status.setText(format(
            "Deleted project metadata; {} remains open as a folder",
            target.root))
}

/*
 * Cedit.beginSwitch
 *
 * Purpose: Begin a project switch. Opening pauses when documents are
 * unsaved so the user can save, discard, or cancel.
 *
 * Parameters:
 *   op — switch operation, such as "open" or "new".
 *
 * Returns: nothing.
 */

void Cedit.beginSwitch(String op) {
    if (activeProject != null) {
        activeProject.workspaceText = captureWorkspace(activeProject.root,
                activeProject.root)
    }

    if (op.equals("open") && firstModifiedDocument() != null) {
        switchOp = op
        pendingCloseAll = true
        pendingCloseDocument = null
        closeChoices.setVisible(true)
        status.setText(
                "Unsaved changes: Save, Discard, or Cancel opening the project")
        updateMenu()
        return
    }

    continueSwitch(op)
}

/*
 * Cedit.continueSwitch
 *
 * Purpose: Continue a project switch, saving the current workspace first
 * when the active project is not the destination.
 *
 * Parameters:
 *   op — switch operation to run after any save.
 *
 * Returns: nothing.
 */

void Cedit.continueSwitch(String op) {
    switchOp = ""
    bool sameRoot = false
    if (activeProject != null && nextProject != null) {
        sameRoot = activeProject.root.equals(nextProject.root)
    }
    if (activeProject != null && !sameRoot) {
        writeProject(activeProject, false, true, op)
        return
    }
    performProjectOp(op)
}

/*
 * Cedit.writeProject
 *
 * Purpose: Write changed project configuration and workspace text, then
 * finish the operation that requested the save.
 *
 * Parameters:
 *   target — project whose metadata is written.
 *   config — true to write project configuration.
 *   workspaceState — true to write workspace text.
 *   op — operation to run after the save.
 *
 * Returns: nothing.
 */

void Cedit.writeProject(
        CwhipProject target,
        bool config,
        bool workspaceState,
        String op) {
    projectOp = op
    projectSaveErrors = ""
    savingProject = target
    bool explicit = (op.equals("save") || op.equals("activate") || op.equals(
            "configure") || op.equals("close"))
    String problem = target.metadataProblem()
    if (!config && !workspaceState) {
        problem = ""
    }
    String configText = ""
    if (config) {
        if (!target.writable) {
            problem = format(
                    "{} has errors; repair it and reopen the project before saving:\n{}", target.configPath, target.errors)
        }
        else {
            configText = target.serialize()
        }
    }
    bool writeWorkspace = (workspaceState && !target.workspaceText.equals(
            target.workspaceOriginal))
    if (workspaceState && !target.workspaceWritable) {
        writeWorkspace = false
        if (explicit && problem.equals("")) {
            problem = format(
                    "{} could not be loaded; repair or remove {} and reopen the project:\n{}", target.workspacePath, target.workspacePath, target.workspaceErrors)
        }
    }
    bool writeConfig = config && !configText.equals(target.original)
    if (problem.equals("") && (writeConfig || writeWorkspace)
            && !System.FileSystem().isDir(
            target.directory)) {
        if (!System.FileSystem().mkdir(target.directory)) {
            problem = format("Could not create {}: {}", target.directory,
                    System.System().lastError())
        }
        else {
            problem = target.metadataProblem()
        }
    }
    if (!problem.equals("")) {
        projectSaveErrors = problem
        finishProjectSave()
        return
    }
    if (writeConfig) {
        target.savingConfig = configText
        projectSaves = projectSaves + 1
        Gtk.Config().save(target.configPath, configText, target.original, _self(
                ).projectConfigSaved)
    }
    if (writeWorkspace) {
        target.savingWorkspace = target.workspaceText
        projectSaves = projectSaves + 1
        Gtk.Config().save(target.workspacePath, target.workspaceText,
                target.workspaceOriginal, _self().projectWorkspaceSaved)
    }
    updateMenu()
    if (projectSaves == 0) {
        finishProjectSave()
    }
}

/*
 * Cedit.projectSaveMessage
 *
 * Purpose: Turn a project-save error into a message, adding a reopen hint
 * when the file changed on disk.
 *
 * Parameters:
 *   path — metadata file that failed to save.
 *   error — raw save error.
 *
 * Returns: text suitable for the failure dialog.
 */

String Cedit.projectSaveMessage(String path, String error) {
    if (error.contains("changed on disk")) {
        return(format(
                "{} changed on disk since it was loaded; reopen the project before saving",
                path))
    }
    return(format("{}: {}", path, error))
}

/*
 * Cedit.addProjectSaveError
 *
 * Purpose: Append one line to the project-save error list.
 *
 * Parameters:
 *   message — error text to record.
 *
 * Returns: nothing.
 */

void Cedit.addProjectSaveError(String message) {
    if (!projectSaveErrors.equals("")) {
        projectSaveErrors.append("\n")
    }
    projectSaveErrors.append(message)
}

/*
 * Cedit.projectConfigSaved
 *
 * Purpose: Record the result of saving project configuration, and finish
 * when every outstanding project save has completed.
 *
 * Parameters:
 *   error — empty on success; otherwise the failure text.
 *
 * Returns: nothing.
 */

void Cedit.projectConfigSaved(String error) {
    projectSaves = projectSaves - 1
    if (error.equals("")) {
        savingProject.original = savingProject.savingConfig
        savingProject.base = savingProject.savingConfig
    }
    else {
        addProjectSaveError(projectSaveMessage(savingProject.configPath, error))
    }
    if (projectSaves == 0) {
        finishProjectSave()
    }
}

/*
 * Cedit.projectWorkspaceSaved
 *
 * Purpose: Record the result of saving workspace state, and finish when
 * every outstanding project save has completed.
 *
 * Parameters:
 *   error — empty on success; otherwise the failure text.
 *
 * Returns: nothing.
 */

void Cedit.projectWorkspaceSaved(String error) {
    projectSaves = projectSaves - 1
    if (error.equals("")) {
        savingProject.workspaceOriginal = savingProject.savingWorkspace
    }
        else {
        addProjectSaveError(projectSaveMessage(
                savingProject.workspacePath,
                error))
    }
    if (projectSaves == 0) {
        finishProjectSave()
    }
}

/*
 * Cedit.finishProjectSave
 *
 * Purpose: After project saves settle, run the pending operation or
 * report the failure, then close the window if a quit was waiting.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.finishProjectSave() {
    String op = projectOp
    String errors = projectSaveErrors
    projectOp = ""
    projectSaveErrors = ""
    savingProject = null
    if (window.disposed()) {
        return
    }
    updateMenu()
    if (errors.equals("")) {
        performProjectOp(op)
    }
    else {
        projectSaveFailed(op, errors)
    }
    if (closeAfterSave && !savePending && projectSaves == 0 && confirmOp.equals(
            "") && !window.disposed()) {
        closeAfterSave = false
        window.close()
    }
}

/*
 * Cedit.projectSaveFailed
 *
 * Purpose: Report a failed project save, or ask whether to continue the
 * operation without saving workspace state.
 *
 * Parameters:
 *   op — operation that was waiting on the save.
 *   errors — combined save error text.
 *
 * Returns: nothing.
 */

void Cedit.projectSaveFailed(String op, String errors) {
    closeAfterSave = false

    if (op.equals("save") || op.equals("configure")) {
        if (op.equals("configure") && configureMessage != null) {
            configureMessage.setText(diagnostic("CEDIT2002", format(
                    "Project save failed: {}; correct the reported path and retry.",
                    errors)))
        }
        projectFailure("Project save failed", errors)
        return
    }

    if (op.equals("activate")) {
        nextProject = null
        projectFailure("Could not write project metadata", errors)
        return
    }
    String accept = "Continue Without Saving"
    if (op.equals("quit")) {
        accept = "Quit Without Saving"
    }
    askConfirm(format("continue-{}", op), format(
            "Could not save workspace state: {}",
            errors), accept)
}

/*
 * Cedit.performProjectOp
 *
 * Purpose: Run a project operation after saves finish: save, configure,
 * close, open, create, activate, switch folder, or quit.
 *
 * Parameters:
 *   op — operation name, such as "save", "open", or "quit".
 *
 * Returns: nothing.
 */

void Cedit.performProjectOp(String op) {
    if (op.equals("save")) {
        status.setText(format("Project saved: {}", activeProject.name))
        return
    }
    if (op.equals("configure")) {
        if (configureMessage != null) {
            configureMessage.setText("Project configuration saved")
        }
        status.setText("Project configuration saved")
        return
    }

    if (op.equals("close")) {
        String root = activeProject.root
        detachProject()
        project.setRoot(root)
        adoptSettingsRoot(root)
        noteOpenFiles()
        forgetProject(root)
        status.setText(format(
                "Closed project; {} remains open as a folder",
                root))
        return
    }

    if (op.equals("open")) {
        CwhipProject target = nextProject
        nextProject = null
        closeAllDocuments()
        activateProject(target, true)
        return
    }
    if (op.equals("new")) {
        writeProject(nextProject, true, true, "activate")
        return
    }
    if (op.equals("activate")) {
        CwhipProject created = nextProject
        nextProject = null
        created.parseWorkspace(created.workspaceOriginal)
        activateProject(created, false)
        status.setText(format("Project saved in {}", created.root))
        return
    }
    if (op.equals("folder")) {
        String root = nextFolder
        detachProject()
        project.setRoot(root)
        adoptSettingsRoot(root)
        nextFolder = ""
        noteOpenFiles()
        return
    }
    if (op.equals("quit")) {
        quitReady = true
        allowWindowClose = true
        window.close()
    }
}

/*
 * Cedit.askConfirm
 *
 * Purpose: Show a confirmation prompt and remember which operation it
 * gates.
 *
 * Parameters:
 *   op — operation to run if the user accepts.
 *   message — prompt text.
 *   accept — label for the accept button.
 *
 * Returns: nothing.
 */

void Cedit.askConfirm(String op, String message, String accept) {
    confirmOp = op
    confirmLabel.setText(message)
    confirmButton.setLabel(accept)
    confirmChoices.setVisible(true)
    status.setText(message)
    updateMenu()
}

/*
 * Cedit.acceptConfirm
 *
 * Purpose: Hide the confirmation prompt and run the operation the user
 * accepted.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.acceptConfirm() {
    String op = confirmOp
    confirmOp = ""
    confirmChoices.setVisible(false)
    updateMenu()
    if (op.equals("delete")) {
        deleteProjectMetadata()
    }
    if (op.equals("replace-new")) {
        startNewProject("new")
    }
    if (op.equals("replace-save-as")) {
        startNewProject("save-as")
    }
    if (op.equals("recover-buffer")) {
        acceptRecovery()
    }
    if (op.startsWith("continue-")) {
        performProjectOp(byteSpan(op, 9, op.length))
    }
}

/*
 * Cedit.cancelConfirm
 *
 * Purpose: Dismiss the confirmation prompt and drop the pending action,
 * restoring a document when none remain.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.cancelConfirm() {
    String op = confirmOp
    confirmOp = ""
    confirmChoices.setVisible(false)
    nextProject = null
    nextFolder = ""
    if (op.equals("recover-buffer")) {
        discardRecovery()
    }
    else {
        status.setText("Cancelled")
    }
    if (op.equals("continue-quit")) {
        allowWindowClose = false
        quitReady = false
    }
    if (documents.length == 0) {
        newDocument()
    }
    updateMenu()
}

