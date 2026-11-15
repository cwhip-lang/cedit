/*
 * src/cwhipProject.cw — CwhipProject config parse and validate.
 * Workspace methods are in cwhipProjectWorkspace.cw.
 *
 * Created: 2026-10-29
 * Author: Auto
 *
 * Changelog:
 *   2026-10-29  Initial file.
 *   2026-11-13  CODING headers and method comments.
 *   2026-11-14  Public members for private-by-default cwhip.
 *   2026-11-15  Apply the revised coding standard.
 *   2026-11-15  Move workspace methods to cwhipProjectWorkspace.cw.
 */

/*
 * The open Cwhip project: .cwhip paths, project.toml settings, and
 * workspace.toml tabs. The editor loads, checks, and writes that
 * metadata through this object.
 */
class CwhipProject {
    public:
    String root
    String directory
    String configPath
    String workspacePath
    String name
    list excludes
    String original
    String base
    String workspaceOriginal
    String workspaceText
    String savingConfig
    String savingWorkspace
    String errors
    String workspaceErrors
    bool writable
    bool workspaceWritable
    bool hasFont
    String fontFamily
    bool hasSize
    int64 fontSize
    bool hasTabs
    int64 tabWidth
    bool hasSpaces
    bool insertSpaces
    bool hasNumbers
    bool lineNumbers
    bool hasWrap
    bool wrap
    bool hasHighlight
    bool highlightLine
    String active
    int64 explorerWidth
    int64 windowWidth
    int64 windowHeight
    list expanded
    list files
    String readError
    bool readMissing
    bool readContent
    String acceptedPath

    /*
     * CwhipProject
     *
     * Purpose: Serialize open tabs/explorer into workspace TOML text.
     *
     * Parameters:
     *   projectRoot.
     *
     * Returns: CwhipProject.
     */

    CwhipProject(String projectRoot) {
        root = projectRoot
        directory = System.FileSystem().join(root, ".cwhip")
        configPath = System.FileSystem().join(directory, "project.toml")
        workspacePath = System.FileSystem().join(directory, "workspace.toml")
        name = System.FileSystem().basename(root)
        if (name.equals("") || name.length > 128) {
            name = "Project"
        }
        excludes = []
        original = ""
        base = ""
        workspaceOriginal = ""
        workspaceText = ""
        savingConfig = ""
        savingWorkspace = ""
        errors = ""
        workspaceErrors = ""
        writable = true
        workspaceWritable = true
        fontFamily = "monospace"
        fontSize = 12
        tabWidth = 4
        insertSpaces = true
        lineNumbers = true
        wrap = false
        highlightLine = false
        resetWorkspace()
        readError = ""
        acceptedPath = ""
    }

    /*
     * resetWorkspace
     *
     * Purpose: Clear the active path, window sizes, expanded folders, and
     * open files so the workspace is empty.
     *
     * Parameters:
     *   none.
     *
     * Returns: nothing.
     */

    void resetWorkspace() {
        active = ""
        explorerWidth = -1
        windowWidth = -1
        windowHeight = -1
        expanded = []
        files = []
    }

    /*
     * error
     *
     * Purpose: Append message to the config errors and mark the project
     * configuration unwritable.
     *
     * Parameters:
     *   message — problem text to record.
     *
     * Returns: nothing.
     */

    void error(String message) {
        if (!errors.equals("")) {
            errors.append("\n")
        }
        errors.append(message)
        writable = false
    }

    /*
     * workspaceError
     *
     * Purpose: Append message, mark the workspace unwritable, and clear
     * any workspace state already parsed.
     *
     * Parameters:
     *   message — problem text to record.
     *
     * Returns: nothing.
     */

    void workspaceError(String message) {
        if (!workspaceErrors.equals("")) {
            workspaceErrors.append("\n")
        }
        workspaceErrors.append(message)
        workspaceWritable = false
        resetWorkspace()
    }

    /*
     * prefix
     *
     * Purpose: Return the project root with a trailing slash.
     *
     * Parameters:
     *   none.
     *
     * Returns: the root, with a slash added when it was missing.
     */

    String prefix() {
        if (root.endsWith("/")) {
            return(root)
        }
        return(format("{}/", root))
    }

    // Root-relative path, or "" when path is outside the root.
    /*
     * relative
     *
     * Purpose: Return the part of path below the project root. The root
     * itself, outside paths, and invalid remainders yield "".
     *
     * Parameters:
     *   path — absolute path to measure against the root.
     *
     * Returns: the root-relative path, or "" when it does not apply.
     */

    String relative(String path) {
        String head = prefix()
        if (!path.startsWith(head) || path.length == head.length) {
            return("")
        }
        String rest = byteSpan(path, head.length, path.length)
        if (!validRelative(rest)) {
            return("")
        }
        return(rest)
    }

    /*
     * hasControl
     *
     * Purpose: Report whether text contains a newline, carriage return,
     * or tab.
     *
     * Parameters:
     *   text — string to scan.
     *
     * Returns: true when one of those characters is present.
     */

    bool hasControl(String text) {
        return(
                text.contains("\n") || text.contains("\r") || text.contains(
                "\t"))
    }

    /*
     * validRelative
     *
     * Purpose: Accept a non-empty root-relative path of at most 4096 bytes.
     * A leading slash, control characters, or empty or dot segments fail.
     *
     * Parameters:
     *   path — candidate relative path.
     *
     * Returns: true when path is safe to store under the root.
     */

    bool validRelative(String path) {
        if (path.equals("") || path.length > 4096 || path.startsWith("/")
                || hasControl(
                path)) {
            return(false)
        }
        list parts = path.split("/")
        int64 i = 0
        while (i < parts.length) {
            String part = parts[i] as String
            if (part.equals("") || part.equals(".") || part.equals("..")) {
                return(false)
            }
            i = i + 1
        }
        return(true)
    }

    // Absolute file path that is not inside this project. `.` and `..` segments
    // are rejected.
    /*
     * validExternal
     *
     * Purpose: Accept an absolute file outside this project. Dot segments,
     * a trailing slash, control characters, or length over 4096 fail.
     *
     * Parameters:
     *   path — absolute path to test.
     *
     * Returns: true when path may be stored as an external file.
     */

    bool validExternal(String path) {
        if (!path.startsWith("/") || path.equals("/") || path.length > 4096
                || hasControl(
                path)) {
            return(false)
        }
        if (path.equals(root) || !relative(path).equals("")) {
            return(false)
        }
        String body = byteSpan(path, 1, path.length)
        if (body.endsWith("/")) {
            return(false)
        }
        return(validRelative(body))
    }

    // Accepts a root-relative path, or an absolute path outside the root.
    // An absolute path inside the root is stored in root-relative form.
    /*
     * acceptWorkspacePath
     *
     * Purpose: Accept stored and remember the kept form in acceptedPath.
     * An absolute path inside the root is stored root-relative.
     *
     * Parameters:
     *   stored — path text from workspace.toml.
     *
     * Returns: true when the path is accepted.
     */

    bool acceptWorkspacePath(String stored) {
        acceptedPath = ""

        if (stored.startsWith("/")) {
            String rel = relative(stored)
            if (!rel.equals("")) {
                acceptedPath = rel
                return(true)
            }
            if (!validExternal(stored)) {
                return(false)
            }
            acceptedPath = stored
            return(true)
        }

        if (!validRelative(stored)) {
            return(false)
        }
        acceptedPath = stored
        return(true)
    }

    /*
     * nameError
     *
     * Purpose: Require 1-128 characters and no newline, return, or tab.
     * Whitespace-only text is rejected.
     *
     * Parameters:
     *   text — candidate project name.
     *
     * Returns: "" when the name is usable, otherwise the error message.
     */

    String nameError(String text) {
        if (text.trim().equals("") || text.length > 128 || hasControl(text)) {
            return(
                    "Project name must be 1-128 characters, without control characters")
        }
        return("")
    }

    /*
     * excludeError
     *
     * Purpose: Require 1-256 characters, no controls, and a relative shape.
     * Leading or trailing slashes and empty or dot segments fail.
     *
     * Parameters:
     *   pattern — candidate exclusion pattern.
     *
     * Returns: "" when the pattern is usable, otherwise the error.
     */

    String excludeError(String pattern) {
        if (pattern.trim().equals("") || pattern.length > 256 || hasControl(
                pattern)) {
            return(
                    "Exclusion patterns must be 1-256 characters, without control characters")
        }
        if (pattern.startsWith("/") || pattern.endsWith("/") || !validRelative(
                pattern)) {
            return(format(
                    "Invalid exclusion pattern {}: use a name or root-relative path without leading/trailing /, ., or .. segments",
                    pattern))
        }
        return("")
    }

    // Refuses symlinked or non-regular metadata so writes and deletes stay
    // inside the project's metadata directory.
    /*
     * metadataProblem
     *
     * Purpose: Allow a missing .cwhip directory. An existing one must be
     * a real directory, and existing toml files must be regular.
     *
     * Parameters:
     *   none.
     *
     * Returns: "" when the metadata paths are usable, otherwise the problem.
     */

    String metadataProblem() {
        if (!System.FileSystem().exists(directory)) {
            return("")
        }
        if (!System.FileSystem().isDir(directory) ||
            !System.FileSystem().absolutePath(
                directory).equals(
                directory)) {
            return(format(
                    "{} must be a real directory, not a file or symbolic link",
                    directory))
        }
        String problem = fileProblem(configPath)
        if (problem.equals("")) {
            problem = fileProblem(workspacePath)
        }
        return(problem)
    }

    /*
     * fileProblem
     *
     * Purpose: Allow a missing file. Otherwise require a regular file at
     * that exact path, not a symbolic link.
     *
     * Parameters:
     *   path — metadata file to check.
     *
     * Returns: "" when missing or regular, otherwise a problem message.
     */

    String fileProblem(String path) {
        if (!System.FileSystem().exists(path)) {
            return("")
        }
        if (!System.FileSystem().isFile(path) ||
            !System.FileSystem().absolutePath(
                path).equals(
                path)) {
            return(format(
                    "{} must be a regular file, not a symbolic link",
                    path))
        }
        return("")
    }

    // readMissing: no file; readContent: bytes were read (readError may still
    // report malformed contents).
    /*
     * readMetadata
     *
     * Purpose: Read up to limit bytes and set readMissing, readContent,
     * and readError. Malformed text is still returned with readError set.
     *
     * Parameters:
     *   path — metadata file to read.
     *   limit — maximum file size in bytes.
     *
     * Returns: the file text when bytes were read, or "" otherwise.
     */

    String readMetadata(String path, int64 limit) {
        readError = ""
        readMissing = false
        readContent = false
        String presence = Gtk.Config().fileStatus(path)
        if (presence.equals("missing")) {
            readMissing = true
            return("")
        }
        if (presence.length > 0) {
            readError = format("Could not read {}: {}", path, presence)
            return("")
        }
        if (!System.FileSystem().isFile(path) || System.FileSystem().fileSize(
                path) > limit) {
            readError = format(
                    "{} must be a regular file no larger than {} KiB", path,
                    limit / 1024)
            return("")
        }
        System.File file = null
        try {
            file = System.File(path, "r")
        }
        except(Exception) {
            readError = format("Could not read {}: {}", path, System.System(
                    ).lastError())
            return("")
        }
        String text = ""
        try {
            text = file.readAll()
        }
        except(Exception) as failure {
            readError = format("Could not read {}: {}", path, failure.message)
        }
        String lastError = System.System().lastError()
        file.close()
        if (readError.equals("") && !lastError.equals("")) {
            readError = format("Could not read {}: {}", path, lastError)
        }
        if (!readError.equals("")) {
            return("")
        }
        readContent = true
        if (!GtkSource.Content().isText(text)) {
            readError = format("Malformed {}: not UTF-8 text", path)
            return(text)
        }
        String malformed = Gtk.Config().validate(text)
        if (!malformed.equals("")) {
            readError = format("Malformed TOML in {}: {}", path, malformed)
        }
        return(text)
    }

    /*
     * value
     *
     * Purpose: Look up section and key in the loaded project text.
     *
     * Parameters:
     *   section — table name; "" selects the document root.
     *   key — name inside that table.
     *
     * Returns: the config value, or "" when the key is absent.
     */

    String value(String section, String key) {
        return(Gtk.Config().value(base, section, key))
    }

    /*
     * table
     *
     * Purpose: Record an error when a top-level key is present but is not
     * a table.
     *
     * Parameters:
     *   text — TOML document to inspect.
     *   key — top-level name that should be a table.
     *
     * Returns: nothing.
     */

    void table(String text, String key) {
        String kind = Gtk.Config().value(text, "", key)
        if (!kind.equals("") && !kind.equals("t")) {
            error(format("{} must be a table", key))
        }
    }

    /*
     * integer
     *
     * Purpose: Read an editor integer inside the given range. A bad value
     * calls error() and returns -1; an absent key returns -1.
     *
     * Parameters:
     *   key — name under the editor table.
     *   minimum — smallest accepted value.
     *   maximum — largest accepted value.
     *
     * Returns: the integer, or -1 when absent or invalid.
     */

    int64 integer(String key, int64 minimum, int64 maximum) {
        String raw = value("editor", key)
        if (raw.equals("")) {
            return(-1)
        }
        if (raw.startsWith("i")) {
            int64 number = byteSpan(raw, 1, raw.length).toInt64()
            if (number >= minimum && number <= maximum) {
                return(number)
            }
        }
        error(format(
                "editor.{} must be an integer from {} to {}",
                key,
                minimum,
                maximum))
        return(-1)
    }

    // -1 inherit (absent or invalid), 0 false, 1 true.
    /*
     * boolean
     *
     * Purpose: Read an editor boolean: 1 true, 0 false, or -1 to inherit.
     * Invalid text calls error(); an absent key does not.
     *
     * Parameters:
     *   key — name under the editor table.
     *
     * Returns: 1 for true, 0 for false, or -1 to inherit.
     */

    int64 boolean(String key) {
        String raw = value("editor", key)
        if (raw.equals("")) {
            return(-1)
        }
        if (raw.equals("btrue")) {
            return(1)
        }
        if (raw.equals("bfalse")) {
            return(0)
        }
        error(format("editor.{} must be a boolean", key))
        return(-1)
    }

    // Returns "" when the project can be opened. Invalid individual values
    // keep it open with errors shown and its configuration unwritable.
    /*
     * load
     *
     * Purpose: Load project.toml and editor overrides, then the workspace.
     * Per-field problems stay recorded and make the config unwritable.
     *
     * Parameters:
     *   settings — preferences used to check a font override.
     *
     * Returns: "" when the project can be opened, otherwise a fatal message.
     */

    String load(CeditSettings settings) {
        String problem = metadataProblem()
        if (!problem.equals("")) {
            return(problem)
        }
        original = readMetadata(configPath, 65536)
        if (readMissing) {
            return(format(
                    "No Cwhip project in {} (missing {}/project.toml); use Project > New Project... to create one",
                    root,
                    directory))
        }
        if (!readError.equals("")) {
            return(readError)
        }
        base = original
        if (!value("", "version").equals("i1")) {
            return(format(
                    "Unsupported project version in {}: expected version = 1",
                    configPath))
        }
        table(base, "project")
        table(base, "explorer")
        table(base, "editor")

        String raw = value("project", "name")
        if (!raw.equals("")) {

            if (!raw.startsWith("s")) {
                error("project.name must be a string")
            }
            else {
                String text = byteSpan(raw, 1, raw.length)
                String nameProblem = nameError(text)
                if (nameProblem.equals("")) {
                    name = text
                }
                else {
                    error(nameProblem)
                }
            }

        }

        raw = value("explorer", "exclude")

        if (!raw.equals("")) {

            if (!raw.equals("x")) {
                error("explorer.exclude must be an array of strings")
            }
            else {

                int64 i = 0
                String item = Gtk.Config().item(base, "explorer", "exclude", 0,
                        "")
                while (!item.equals("")) {

                    if (!item.startsWith("s")) {
                        error("explorer.exclude must be an array of strings")
                    }
                    else {
                        String pattern = byteSpan(item, 1, item.length)
                        String patternProblem = excludeError(pattern)
                        if (patternProblem.equals("")) {
                            excludes.append(pattern)
                        }
                        else {
                            error(patternProblem)
                        }
                    }

                    i = i + 1
                    item = Gtk.Config().item(base, "explorer", "exclude", i, "")
                }

            }

        }

        raw = value("editor", "font_family")

        if (!raw.equals("")) {

            if (!raw.startsWith("s")) {
                error("editor.font_family must be a string")
            }
            else {
                String font = byteSpan(raw, 1, raw.length)
                String fontProblem = settings.fontError(font)
                if (fontProblem.equals("")) {
                    hasFont = true
                    fontFamily = font
                }
                else {
                    error(format("editor.font_family: {}", fontProblem))
                }
            }

        }

        int64 number = integer("font_size", 6, 72)
        hasSize = number > 0
        if (hasSize) {
            fontSize = number
        }
        number = integer("tab_width", 1, 16)
        hasTabs = number > 0
        if (hasTabs) {
            tabWidth = number
        }
        number = boolean("insert_spaces")
        hasSpaces = number >= 0
        insertSpaces = number == 1
        number = boolean("line_numbers")
        hasNumbers = number >= 0
        lineNumbers = number == 1
        number = boolean("wrap")
        hasWrap = number >= 0
        wrap = number == 1
        number = boolean("highlight_current_line")
        hasHighlight = number >= 0
        highlightLine = number == 1
        loadWorkspace()
        return("")
    }

    void loadWorkspace()
    String wsInteger(String text, String key, int64 minimum, int64 maximum)
    int64 wsNumber(String text, String key)
    String parseWorkspace(String text)
    bool validPosition(String raw)
    String quotedList(list values)
    String excludeLines()
    String serialize()
    void copyConfiguration(CwhipProject source)
    String overrideSummary()
    int64 byteSpanBound(int64 value, int64 length)
    String byteSpan(String text, int64 first, int64 last)
}

include "cwhipProjectWorkspace.cw"
