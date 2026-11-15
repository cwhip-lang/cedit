/*
 * src/languageFormat.cw — document and range formatting on LanguageClient.
 *
 * Created: 2026-11-15
 * Author: Auto
 *
 * Changelog:
 *   2026-11-15  Initial file.
 */

/*
 * Whether body is the initialize result (numeric id 1 and a result).
 *
 * Purpose: distinguish initialize from later results whose ids only
 * start with the digit 1.
 *
 * Parameters:
 *   body — JSON-RPC message body.
 *
 * Returns: true when this message is the initialize result.
 */
bool LanguageClient.isInitializeResult(String body) {
    if (jsonId(body) != 1) {
        return(false)
    }
    return(body.contains("\"result\""))
}

/*
 * Read the numeric JSON-RPC id.
 *
 * Purpose: parse the first "id" number, skipping spaces after the colon.
 *
 * Parameters:
 *   body — JSON-RPC message body.
 *
 * Returns: the id, or -1 when it is missing or not a number.
 */
int64 LanguageClient.jsonId(String body) {
    int64 at = body.find("\"id\":")
    if (at < 0) {
        return(-1)
    }
    return(leadingInteger(byteSpan(body, at + 5, body.length).trim()))
}

/*
 * Skip ASCII space, tab, CR, and LF.
 *
 * Purpose: move an index to the next meaningful JSON character.
 *
 * Parameters:
 *   text — source text.
 *   index — start index.
 *
 * Returns: the first non-space index, or text.length.
 */
int64 LanguageClient.skipSpace(String text, int64 index) {
    while (index < text.length) {
        uint8 byte = text[index]
        if (byte != 32 && byte != 9 && byte != 10 && byte != 13) {
            break
        }
        index = index + 1
    }
    return(index)
}

/*
 * Whether an initialize capability enables a provider.
 *
 * Purpose: true for JSON true or an options object; false when absent
 * or false.
 *
 * Parameters:
 *   body — initialize result body.
 *   name — capability field name.
 *
 * Returns: true when the provider is offered.
 */
bool LanguageClient.capabilityEnabled(String body, String name) {
    String key = format("\"{}\"", name)
    int64 at = body.find(key)
    if (at < 0) {
        return(false)
    }
    int64 index = skipSpace(body, at + key.length)
    if (index >= body.length || body[index] != 58) {
        return(false)
    }
    index = skipSpace(body, index + 1)
    if (index >= body.length) {
        return(false)
    }
    if (body[index] == 123) {
        return(true)
    }
    if (index + 4 > body.length) {
        return(false)
    }
    if (!byteSpan(body, index, index + 4).equals("true")) {
        return(false)
    }
    if (index + 4 < body.length) {
        uint8 next = body[index + 4]
        bool letter = (next >= 65 && next <= 90) || (next >= 97 && next <= 122)
        bool digit = next >= 48 && next <= 57
        if (letter || digit) {
            return(false)
        }
    }
    return(true)
}

/*
 * Find the last needle that starts before limit.
 *
 * Purpose: locate the range object that belongs to a newText field.
 *
 * Parameters:
 *   text — source text.
 *   needle — substring to find.
 *   limit — exclusive end index.
 *
 * Returns: the start index, or -1 when needle is absent before limit.
 */
int64 LanguageClient.findLast(String text, String needle, int64 limit) {
    int64 found = -1
    int64 offset = 0
    while (offset < limit) {
        String rest = byteSpan(text, offset, limit)
        int64 at = rest.find(needle)
        if (at < 0) {
            break
        }
        found = offset + at
        offset = found + 1
    }
    return(found)
}

/*
 * Read one hex digit.
 *
 * Purpose: decode a JSON \u escape.
 *
 * Parameters:
 *   byte — ASCII character.
 *
 * Returns: 0-15, or -1 when byte is not hex.
 */
int64 LanguageClient.hexDigit(uint8 byte) {
    if (byte >= 48 && byte <= 57) {
        return(byte - 48)
    }
    if (byte >= 97 && byte <= 102) {
        return(byte - 97 + 10)
    }
    if (byte >= 65 && byte <= 70) {
        return(byte - 65 + 10)
    }
    return(-1)
}

/*
 * Read four hex digits.
 *
 * Purpose: decode the code point in a JSON \u escape.
 *
 * Parameters:
 *   text — source text.
 *   origin — index of the first hex digit.
 *
 * Returns: the code point, or -1 when four hex digits are not present.
 */
int64 LanguageClient.hexValue(String text, int64 origin) {
    int64 code = 0
    int64 index = 0
    while (index < 4) {
        if (origin + index >= text.length) {
            return(-1)
        }
        int64 digit = hexDigit(text[origin + index])
        if (digit < 0) {
            return(-1)
        }
        code = code * 16 + digit
        index = index + 1
    }
    return(code)
}

/*
 * Append one Unicode code point as UTF-8.
 *
 * Purpose: turn a JSON \u escape into the bytes the editor stores.
 *
 * Parameters:
 *   value — string that receives the bytes.
 *   code — BMP code point.
 *
 * Returns: nothing.
 */
void LanguageClient.appendCode(String value, int64 code) {
    if (code < 0) {
        return
    }
    inline (String value, int64 code) {
        unsigned int point = (unsigned int)(*code);
        char bytes[3];
        int length = 0;
        if (point < 0x80u) {
            bytes[0] = (char)point;
            length = 1;
        } else if (point < 0x800u) {
            bytes[0] = (char)(0xC0u | (point >> 6));
            bytes[1] = (char)(0x80u | (point & 0x3Fu));
            length = 2;
        } else if (point <= 0xFFFFu) {
            bytes[0] = (char)(0xE0u | (point >> 12));
            bytes[1] = (char)(0x80u | ((point >> 6) & 0x3Fu));
            bytes[2] = (char)(0x80u | (point & 0x3Fu));
            length = 3;
        }
        if (length > 0) {
            cwhip_string_append_bytes(*value, bytes, (uint64_t)length);
        }
    }
}

/*
 * Decode a JSON string and record the index after its closing quote.
 *
 * Purpose: read newText, including short escapes and \u code points.
 * scanAt is -1 when the closing quote is missing.
 *
 * Parameters:
 *   body — JSON text.
 *   origin — index of the first character inside the quotes.
 *
 * Returns: the decoded string.
 */
String LanguageClient.takeString(String body, int64 origin) {
    String value = ""
    int64 index = origin
    while (index < body.length) {
        uint8 byte = body[index]
        if (byte == 92 && index + 1 < body.length) {
            uint8 escaped = body[index + 1]
            if (escaped == 110) {
                value.append("\n")
            }
            else(escaped == 114) {
                value.append("\r")
            }
            else(escaped == 116) {
                value.append("\t")
            }
            else(escaped == 117) {
                int64 code = hexValue(body, index + 2)
                if (code >= 0) {
                    appendCode(value, code)
                    index = index + 6
                    continue
                }
                value.append(body[(index + 1)..(index + 1)])
            }
            else {
                value.append(body[(index + 1)..(index + 1)])
            }
            index = index + 2
        }
        else {
            if (byte == 34) {
                scanAt = index + 1
                return(value)
            }
            value.append(body[index..(index)])
            index = index + 1
        }
    }
    scanAt = -1
    return(value)
}

/*
 * Read a non-negative integer after a JSON label.
 *
 * Purpose: parse line and character fields. scanAt stops after the
 * digits so the next field can be read from there.
 *
 * Parameters:
 *   text — slice that contains the field.
 *   label — quoted field name plus colon, such as "\"line\":".
 *   offset — index to start searching.
 *
 * Returns: the integer, or -1 when the field is missing.
 */
int64 LanguageClient.readLabeled(String text, String label, int64 offset) {
    String rest = byteSpan(text, offset, text.length)
    int64 at = rest.find(label)
    if (at < 0) {
        return(-1)
    }
    int64 origin = skipSpace(text, offset + at + label.length)
    int64 value = leadingInteger(byteSpan(text, origin, text.length))
    scanAt = origin
    if (value < 0) {
        return(-1)
    }
    while (scanAt < text.length) {
        uint8 byte = text[scanAt]
        if (byte < 48 || byte > 57) {
            break
        }
        scanAt = scanAt + 1
    }
    return(value)
}

/*
 * Whether document is still in the editor's open list.
 *
 * Purpose: ignore a formatting result for a tab that has closed.
 *
 * Parameters:
 *   document — document the request was sent for.
 *
 * Returns: true when that object is still open.
 */
bool LanguageClient.documentListed(EditorDocument document) {
    int64 index = 0
    while (index < editor.documents.length) {
        EditorDocument item = editor.documents[index] as EditorDocument
        if (item == document) {
            return(true)
        }
        index = index + 1
    }
    return(false)
}

/*
 * Build a formatting or range-formatting request body.
 *
 * Purpose: send the document uri, the selection when ranged, and the
 * editor tab size and insert-spaces options.
 *
 * Parameters:
 *   ranged — true for textDocument/rangeFormatting.
 *   uri — file URI of the document.
 *   startLine — 0-based start line.
 *   startCharacter — 0-based start character.
 *   endLine — 0-based end line.
 *   endCharacter — 0-based end character.
 *
 * Returns: the JSON-RPC body, without the Content-Length header.
 */
String LanguageClient.formatRequestBody(
        bool ranged,
        String uri,
        int64 startLine,
        int64 startCharacter,
        int64 endLine,
        int64 endCharacter) {
    String spaces = "false"
    if (editor.effectiveInsertSpaces()) {
        spaces = "true"
    }
    String body = "{\"jsonrpc\":\"2.0\",\"id\":"
    body.append(format("{}", formatRequest))
    body.append(",\"method\":\"")
    if (ranged) {
        body.append("textDocument/rangeFormatting")
    }
    else {
        body.append("textDocument/formatting")
    }
    body.append("\",\"params\":{\"textDocument\":{\"uri\":\"")
    body.append(escape(uri))
    body.append("\"}")
    if (ranged) {
        body.append(",\"range\":{\"start\":{\"line\":")
        body.append(format("{}", startLine))
        body.append(",\"character\":")
        body.append(format("{}", startCharacter))
        body.append("},\"end\":{\"line\":")
        body.append(format("{}", endLine))
        body.append(",\"character\":")
        body.append(format("{}", endCharacter))
        body.append("}}")
    }
    body.append(",\"options\":{\"tabSize\":")
    body.append(format("{}", editor.effectiveTabWidth()))
    body.append(",\"insertSpaces\":")
    body.append(spaces)
    body.append("}}}")
    return(body)
}

/*
 * Copy a selection into an LSP range.
 *
 * Purpose: read the selection edges and clamp each one at zero.
 *
 * Parameters:
 *   document — document that owns the selection.
 *
 * Returns: the 0-based range. Each edge is at least zero.
 */
FormatEdit LanguageClient.readSelection(EditorDocument document) {
    FormatEdit selection = FormatEdit()
    selection.startLine = document.view.selectionStartLine() - 1
    selection.startCharacter = document.view.selectionStartColumn() - 1
    selection.endLine = document.view.selectionEndLine() - 1
    selection.endCharacter = document.view.selectionEndColumn() - 1
    if (selection.startLine < 0) {
        selection.startLine = 0
    }
    if (selection.startCharacter < 0) {
        selection.startCharacter = 0
    }
    if (selection.endLine < 0) {
        selection.endLine = 0
    }
    if (selection.endCharacter < 0) {
        selection.endCharacter = 0
    }
    return(selection)
}

/*
 * Ask the language server to format a document or a selection.
 *
 * Purpose: send textDocument/formatting, or textDocument/rangeFormatting
 * when ranged. A missing selection, a server that is not ready, a file
 * the server does not handle, or a provider the server did not advertise
 * leaves the buffer unchanged and reports the failure on the status line.
 *
 * Parameters:
 *   document — buffer to format; may be null.
 *   ranged — true to format the current selection.
 *
 * Returns: nothing. The result is applied when the response arrives.
 */
void LanguageClient.requestFormat(EditorDocument document, bool ranged) {
    if (document == null) {
        editor.status.setText("No document to format")
        return
    }
    if (ranged && !document.view.hasSelection()) {
        editor.status.setText("No selection to format")
        return
    }
    if (!running) {
        editor.status.setText("Language server is not running")
        return
    }
    if (!ready) {
        editor.status.setText("Language server is not ready")
        return
    }
    if (!handles(document.path)) {
        editor.status.setText("Language server does not handle this file")
        return
    }
    bool supported = canFormat
    if (ranged) {
        supported = canRangeFormat
    }
    if (!supported) {
        editor.status.setText("Language server does not support formatting")
        return
    }
    FormatEdit selection = FormatEdit()
    if (ranged) {
        selection = readSelection(document)
    }
    if (generation != sentGeneration) {
        sendChange(document)
    }
    formatRequest = nextRequest
    nextRequest = nextRequest + 1
    formatDocument = document
    formatVersion = document.lspVersion
    formatGeneration = generation
    String body = formatRequestBody(ranged, fileUri(document.path),
            selection.startLine, selection.startCharacter, selection.endLine,
            selection.endCharacter)
    writeFrame(body)
    if (!running) {
        formatRequest = 0
        formatDocument = null
    }
}

/*
 * Apply parsed formatting edits in reverse order.
 *
 * Purpose: one undo group. An empty edit list reports that nothing
 * changed. Positions are converted from 0-based LSP to 1-based view
 * coordinates.
 *
 * Parameters:
 *   document — open document the edits belong to.
 *   edits — FormatEdit values from the response.
 *
 * Returns: nothing.
 */
void LanguageClient.applyFormatEdits(EditorDocument document, list edits) {
    if (edits.length == 0) {
        editor.status.setText("No formatting changes")
        return
    }
    document.view.beginUserAction()
    int64 index = edits.length - 1
    while (index >= 0) {
        FormatEdit edit = edits[index] as FormatEdit
        document.view.replaceRange(edit.startLine + 1, edit.startCharacter + 1,
                edit.endLine + 1, edit.endCharacter + 1, edit.newText)
        index = index - 1
    }
    document.view.endUserAction()
    editor.status.setText("Formatted")
}

/*
 * Parse the result array and apply it, or report a bad payload.
 *
 * Purpose: leave the buffer unchanged when the result is not a text-edit
 * array. An empty array reports no changes.
 *
 * Parameters:
 *   document — document that receives the edits.
 *   body — JSON-RPC response body.
 *   resultAt — index of the "result" field.
 *
 * Returns: nothing.
 */
void LanguageClient.applyFormatResult(
        EditorDocument document,
        String body,
        int64 resultAt) {
    int64 index = skipSpace(body, resultAt + 9)
    if (index >= body.length || body[index] != 91) {
        editor.status.setText("Language server format failed: missing result")
        return
    }
    int64 next = skipSpace(body, index + 1)
    if (next < body.length && body[next] == 93) {
        editor.status.setText("No formatting changes")
        return
    }

    list edits = []
    int64 cursor = resultAt
    while (true) {
        String rest = byteSpan(body, cursor, body.length)
        int64 at = rest.find("\"newText\":\"")
        if (at < 0) {
            break
        }
        int64 textAt = cursor + at
        int64 rangeAt = findLast(body, "\"range\":", textAt)
        if (rangeAt < cursor) {
            editor.status.setText("Language server format failed: bad edit")
            return
        }
        String slice = byteSpan(body, rangeAt, textAt)
        int64 startLine = readLabeled(slice, "\"line\":", 0)
        int64 startCharacter = readLabeled(slice, "\"character\":", scanAt)
        int64 endLine = readLabeled(slice, "\"line\":", scanAt)
        int64 endCharacter = readLabeled(slice, "\"character\":", scanAt)
        String newText = takeString(body, textAt + 11)
        if (startLine < 0 || startCharacter < 0 || endLine < 0 ||
                endCharacter < 0 || scanAt < 0) {
            editor.status.setText("Language server format failed: bad edit")
            return
        }
        FormatEdit edit = FormatEdit()
        edit.startLine = startLine
        edit.startCharacter = startCharacter
        edit.endLine = endLine
        edit.endCharacter = endCharacter
        edit.newText = newText
        edits.append(edit)
        cursor = scanAt
    }

    if (edits.length == 0) {
        editor.status.setText("Language server format failed: bad edit")
        return
    }
    applyFormatEdits(document, edits)
}

/*
 * Handle a formatting response when it matches the pending request.
 *
 * Purpose: apply text edits, or report an error and leave the buffer
 * unchanged. A document edited since the request is left unchanged.
 *
 * Parameters:
 *   body — JSON-RPC message body.
 *
 * Returns: true when this message was the pending formatting response.
 */
bool LanguageClient.acceptFormat(String body) {
    if (formatRequest == 0 || jsonId(body) != formatRequest) {
        return(false)
    }
    EditorDocument document = formatDocument
    formatRequest = 0
    formatDocument = null
    if (document == null || !documentListed(document)) {
        return(true)
    }
    bool sameVersion = document.lspVersion == formatVersion
    bool sameGeneration = generation == formatGeneration
    if (!sameVersion || !sameGeneration) {
        editor.status.setText(
                "Language server format failed: document changed")
        return(true)
    }
    int64 errorAt = body.find("\"error\":")
    int64 resultAt = body.find("\"result\":")
    if (errorAt >= 0 && (resultAt < 0 || errorAt < resultAt)) {
        String message = "format failed"
        int64 messageAt = body.find("\"message\":\"")
        if (messageAt >= 0) {
            message = readString(body, messageAt + 11)
        }
        editor.status.setText(format(
                "Language server format failed: {}",
                message))
        return(true)
    }
    if (resultAt < 0) {
        editor.status.setText("Language server format failed: missing result")
        return(true)
    }
    applyFormatResult(document, body, resultAt)
    return(true)
}
