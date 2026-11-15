/*
 * src/cwhipProjectWorkspace.cw — Workspace parse and serialize for
 * CwhipProject. Definitions are out of line. The class and the
 * project.toml helpers stay in cwhipProject.cw.
 *
 * Created: 2026-11-15
 * Author: Auto
 *
 * Changelog:
 *   2026-11-15  Split workspace methods out of cwhipProject.cw.
 */

/*
 * loadWorkspace
 *
 * Purpose: Read workspace.toml, storing empty original text if it is
 * missing. A bad file records a workspace error and clears state.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void CwhipProject.loadWorkspace() {
    workspaceOriginal = readMetadata(workspacePath, 1048576)
    if (readMissing) {
        workspaceOriginal = ""
        return
    }
    if (!readError.equals("")) {
        workspaceError(readError)
        return
    }
    String problem = parseWorkspace(workspaceOriginal)
    if (!problem.equals("")) {
        workspaceError(problem)
    }
}

/*
 * wsInteger
 *
 * Purpose: Read a workspace integer as digits, or as an error sentence.
 * An absent key returns an empty string.
 *
 * Parameters:
 *   text — workspace TOML to read.
 *   key — name under the workspace table.
 *   minimum — smallest accepted value.
 *   maximum — largest accepted value.
 *
 * Returns: "" if absent, digits if valid, or an error message.
 */

String CwhipProject.wsInteger(String text, String key, int64 minimum, int64 maximum) {
    String raw = Gtk.Config().value(text, "workspace", key)
    if (raw.equals("")) {
        return("")
    }
    if (raw.startsWith("i")) {
        int64 number = byteSpan(raw, 1, raw.length).toInt64()
        if (number >= minimum && number <= maximum) {
            return(format("{}", number))
        }
    }
    return(format(
            "workspace.{} must be an integer from {} to {}",
            key,
            minimum,
            maximum))
}

/*
 * wsNumber
 *
 * Purpose: Parse workspace.key, skipping its type prefix.
 *
 * Parameters:
 *   text — workspace TOML to read.
 *   key — name under the workspace table.
 *
 * Returns: the integer, or -1 when the key is absent.
 */

int64 CwhipProject.wsNumber(String text, String key) {
    String raw = Gtk.Config().value(text, "workspace", key)
    if (raw.equals("")) {
        return(-1)
    }
    return(byteSpan(raw, 1, raw.length).toInt64())
}

// Parses workspace TOML; returns "" or the first problem. Any problem
// discards the whole workspace rather than restoring part of it.
/*
 * parseWorkspace
 *
 * Purpose: Apply text to the workspace fields. The first problem
 * clears those fields and is returned.
 *
 * Parameters:
 *   text — workspace.toml contents.
 *
 * Returns: "" when the workspace is usable, otherwise the first problem.
 */

String CwhipProject.parseWorkspace(String text) {
    resetWorkspace()
    if (!Gtk.Config().value(text, "", "version").equals("i1")) {
        return(format(
                "Unsupported workspace version in {}: expected version = 1",
                workspacePath))
    }
    String kind = Gtk.Config().value(text, "", "workspace")
    if (kind.equals("")) {
        return("")
    }
    if (!kind.equals("t")) {
        return("workspace must be a table")
    }

    String raw = Gtk.Config().value(text, "workspace", "active")
    if (!raw.equals("")) {

        if (!raw.startsWith("s") || !acceptWorkspacePath(byteSpan(
                raw,
                1,
                raw.length))) {
            return(
                    "workspace.active must be a path inside the project or an absolute path outside it")
        }

        active = acceptedPath
    }

    // wsInteger yields digits when valid; messages always contain spaces.
    String problem = wsInteger(text, "explorer_width", 0, 5000)
    if (problem.contains(" ")) {
        return(problem)
    }
    problem = wsInteger(text, "window_width", 200, 10000)
    if (problem.contains(" ")) {
        return(problem)
    }
    problem = wsInteger(text, "window_height", 150, 10000)
    if (problem.contains(" ")) {
        return(problem)
    }
    explorerWidth = wsNumber(text, "explorer_width")
    windowWidth = wsNumber(text, "window_width")
    windowHeight = wsNumber(text, "window_height")
    raw = Gtk.Config().value(text, "workspace", "expanded")
    if (!raw.equals("") && !raw.equals("x")) {
        return("workspace.expanded must be an array of paths")
    }

    int64 i = 0
    String item = Gtk.Config().item(text, "workspace", "expanded", 0, "")
    while (!item.equals("")) {
        if (!item.startsWith("s") || !validRelative(byteSpan(
                item,
                1,
                item.length))) {
            resetWorkspace()
            return("workspace.expanded must contain root-relative paths")
        }
        expanded.append(byteSpan(item, 1, item.length))
        i = i + 1
        item = Gtk.Config().item(text, "workspace", "expanded", i, "")
    }

    raw = Gtk.Config().value(text, "workspace", "files")
    if (!raw.equals("") && !raw.equals("x")) {
        return("workspace.files must be an array of tables")
    }
    i = 0
    item = Gtk.Config().item(text, "workspace", "files", 0, "")

    while (!item.equals("")) {
        String path = Gtk.Config().item(text, "workspace", "files", i,
                "path")
        String line = Gtk.Config().item(text, "workspace", "files", i,
                "line")
        String column = Gtk.Config().item(text, "workspace", "files", i,
                "column")
        if (!item.equals("t") || !path.startsWith("s") ||
            !acceptWorkspacePath(byteSpan(
                path,
                1,
                path.length)) ||
            !validPosition(
                line) || !validPosition(
                column)) {
            resetWorkspace()
            return(
                    "workspace.files entries must be tables with a path inside the project or an absolute path outside it, and a positive line/column")
        }
        files.append(WorkspaceFile(acceptedPath, byteSpan(line, 1,
                line.length).toInt64(),
            byteSpan(column, 1, column.length).toInt64()))
        i = i + 1
        item = Gtk.Config().item(text, "workspace", "files", i, "")
    }

    return("")
}

/*
 * validPosition
 *
 * Purpose: Accept an i-prefixed integer from 1 through 100000000.
 *
 * Parameters:
 *   raw — config integer token for a line or column.
 *
 * Returns: true when raw is inside that range.
 */

bool CwhipProject.validPosition(String raw) {
    if (!raw.startsWith("i")) {
        return(false)
    }
    int64 number = byteSpan(raw, 1, raw.length).toInt64()
    return(number >= 1 && number <= 100000000)
}

/*
 * quotedList
 *
 * Purpose: Format strings as a TOML array of quoted values.
 *
 * Parameters:
 *   values — strings to quote and join.
 *
 * Returns: a bracketed TOML array, "[]" when values is empty.
 */

String CwhipProject.quotedList(list values) {
    String text = "["
    int64 i = 0
    while (i < values.length) {
        if (i > 0) {
            text.append(", ")
        }
        text.append(Gtk.Config().quote(values[i] as String))
        i = i + 1
    }
    text.append("]")
    return(text)
}

/*
 * excludeLines
 *
 * Purpose: Join the exclusion patterns with newline characters.
 *
 * Parameters:
 *   none.
 *
 * Returns: one pattern per line, or "" when none are set.
 */

String CwhipProject.excludeLines() {
    String text = ""
    int64 i = 0
    while (i < excludes.length) {
        if (i > 0) {
            text.append("\n")
        }
        text.append(excludes[i] as String)
        i = i + 1
    }
    return(text)
}

// Keeps unknown keys from the merge base; removed overrides fall back to
// inheritance by deleting their keys.
/*
 * serialize
 *
 * Purpose: Serialize settings and save via Gtk.Config when the on-disk text
 * still matches.
 *
 * Parameters:
 *   none.
 *
 * Returns: String.
 */

String CwhipProject.serialize() {
    String text = base
    if (text.equals("")) {
        text = "version = 1\n"
    }
    if (!hasFont) {
        text = Gtk.Config().remove(text, "editor", "font_family")
    }
    if (!hasSize) {
        text = Gtk.Config().remove(text, "editor", "font_size")
    }
    if (!hasTabs) {
        text = Gtk.Config().remove(text, "editor", "tab_width")
    }
    if (!hasSpaces) {
        text = Gtk.Config().remove(text, "editor", "insert_spaces")
    }
    if (!hasNumbers) {
        text = Gtk.Config().remove(text, "editor", "line_numbers")
    }
    if (!hasWrap) {
        text = Gtk.Config().remove(text, "editor", "wrap")
    }
    if (!hasHighlight) {
        text = Gtk.Config().remove(text, "editor", "highlight_current_line")
    }
    String updates = format(
            "version = 1\n[project]\nname = {}\n[explorer]\nexclude = {}\n",
        Gtk.Config().quote(name), quotedList(excludes))
    String editor = ""
    if (hasFont) {
        editor.append(format("font_family = {}\n", Gtk.Config().quote(
                fontFamily)))
    }
    if (hasSize) {
        editor.append(format("font_size = {}\n", fontSize))
    }
    if (hasTabs) {
        editor.append(format("tab_width = {}\n", tabWidth))
    }
    if (hasSpaces) {
        editor.append(format("insert_spaces = {}\n", insertSpaces))
    }
    if (hasNumbers) {
        editor.append(format("line_numbers = {}\n", lineNumbers))
    }
    if (hasWrap) {
        editor.append(format("wrap = {}\n", wrap))
    }
    if (hasHighlight) {
        editor.append(
                format(
                "highlight_current_line = {}\n",
                highlightLine))
    }
    if (!editor.equals("")) {
        updates.append("[editor]\n")
        updates.append(editor)
    }
    return(Gtk.Config().merge(text, updates))
}

// Copies configuration (including unknown keys) for Save As.
/*
 * copyConfiguration
 *
 * Purpose: Copy the name, exclusions, editor overrides, and base text.
 * Unknown keys in that text are kept; workspace fields are not.
 *
 * Parameters:
 *   source — project whose configuration is copied.
 *
 * Returns: nothing.
 */

void CwhipProject.copyConfiguration(CwhipProject source) {
    base = source.base
    name = source.name
    excludes = []
    int64 i = 0
    while (i < source.excludes.length) {
        excludes.append(source.excludes[i] as String)
        i = i + 1
    }
    hasFont = source.hasFont
    fontFamily = source.fontFamily
    hasSize = source.hasSize
    fontSize = source.fontSize
    hasTabs = source.hasTabs
    tabWidth = source.tabWidth
    hasSpaces = source.hasSpaces
    insertSpaces = source.insertSpaces
    hasNumbers = source.hasNumbers
    lineNumbers = source.lineNumbers
    hasWrap = source.hasWrap
    wrap = source.wrap
    hasHighlight = source.hasHighlight
    highlightLine = source.highlightLine
}

/*
 * overrideSummary
 *
 * Purpose: List the editor settings this project overrides, by name.
 *
 * Parameters:
 *   none.
 *
 * Returns: a comma-separated list, or "" when nothing is overridden.
 */

String CwhipProject.overrideSummary() {
    list names = []
    if (hasFont) {
        names.append("font family")
    }
    if (hasSize) {
        names.append("font size")
    }
    if (hasTabs) {
        names.append("tab width")
    }
    if (hasSpaces) {
        names.append("insert spaces")
    }
    if (hasNumbers) {
        names.append("line numbers")
    }
    if (hasWrap) {
        names.append("wrap")
    }
    if (hasHighlight) {
        names.append("highlight current line")
    }
    String text = ""
    int64 i = 0
    while (i < names.length) {
        if (i > 0) {
            text.append(", ")
        }
        text.append(names[i] as String)
        i = i + 1
    }
    return(text)
}

/*
 * byteSpanBound
 *
 * Purpose: extract substrings for goto-line parsing and recovery
 *
 * Parameters:
 *   value.
 *   length.
 *
 * Returns: int64.
 */

int64 CwhipProject.byteSpanBound(int64 value, int64 length) {
    int64 index = value
    if (index < 0) {
        index = index + length
    }
    if (index < 0) {
        return(0)
    }
    if (index > length) {
        return(length)
    }
    return(index)
}
/*
 * byteSpan
 *
 * Purpose: Return text from first inclusive to last exclusive.
 * Negative indexes count backward from the end of text.
 *
 * Parameters:
 *   text — source string.
 *   first — inclusive start index.
 *   last — exclusive end index.
 *
 * Returns: the slice, or "" when the span is empty.
 */

String CwhipProject.byteSpan(String text, int64 first, int64 last) {
    int64 lower = byteSpanBound(first, text.length)
    int64 end = byteSpanBound(last, text.length)
    if (end <= lower) {
        return("")
    }
    return(text[lower..(end - 1)])
}
