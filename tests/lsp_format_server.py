#!/usr/bin/env python3
"""Stdio language server for cedit formatting tests.

Modes:
  support       advertise both formatting providers and answer them
  unsupported   advertise neither provider; reject the request if sent
  reject        advertise both providers, then answer with method not found

The installed cwhip-lsp is not used. Every message body is appended to the
log path given on the command line.
"""

import json
import sys


def read_message():
    length = 0
    while True:
        line = sys.stdin.buffer.readline()
        if not line:
            return None
        if line in (b"\r\n", b"\n"):
            break
        if line.lower().startswith(b"content-length:"):
            length = int(line.split(b":", 1)[1].strip())
    if length <= 0:
        return None
    body = sys.stdin.buffer.read(length)
    if len(body) != length:
        return None
    return body.decode("utf-8")


def send(payload):
    body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    sys.stdout.buffer.write(f"Content-Length: {len(body)}\r\n\r\n".encode("ascii"))
    sys.stdout.buffer.write(body)
    sys.stdout.buffer.flush()


def end_position(text):
    line = 0
    character = 0
    for value in text:
        if value == "\n":
            line += 1
            character = 0
        else:
            character += 1
    return line, character


def document_uri(message):
    document = (message.get("params") or {}).get("textDocument") or {}
    return document.get("uri", "")


def main():
    mode = sys.argv[1]
    log_path = sys.argv[2]
    documents = {}
    with open(log_path, "w", encoding="utf-8") as log:
        while True:
            text = read_message()
            if text is None:
                return 0
            log.write(text + "\n")
            log.flush()
            message = json.loads(text)
            method = message.get("method", "")
            if method == "initialize":
                capabilities = {"textDocumentSync": 1}
                if mode != "unsupported":
                    capabilities["documentFormattingProvider"] = True
                    capabilities["documentRangeFormattingProvider"] = True
                send({"jsonrpc": "2.0", "id": message.get("id"),
                      "result": {"capabilities": capabilities}})
                continue
            if method == "exit":
                return 0
            if method == "shutdown":
                if "id" in message:
                    send({"jsonrpc": "2.0", "id": message.get("id"), "result": None})
                continue
            if method == "textDocument/didOpen":
                document = (message.get("params") or {}).get("textDocument") or {}
                documents[document.get("uri", "")] = document.get("text", "")
                continue
            if method == "textDocument/didChange":
                params = message.get("params") or {}
                changes = params.get("contentChanges") or []
                stored = ""
                if changes and isinstance(changes[-1], dict):
                    stored = changes[-1].get("text", "")
                documents[document_uri(message)] = stored
                continue
            if method in ("textDocument/formatting", "textDocument/rangeFormatting"):
                if mode != "support":
                    send({"jsonrpc": "2.0", "id": message.get("id"),
                          "error": {"code": -32601, "message": "method not found"}})
                    continue
                if method == "textDocument/rangeFormatting":
                    edit_range = (message.get("params") or {}).get("range") or {
                        "start": {"line": 0, "character": 0},
                        "end": {"line": 0, "character": 0},
                    }
                    new_text = "GAMMA"
                else:
                    stored = documents.get(document_uri(message), "")
                    line, character = end_position(stored)
                    edit_range = {
                        "start": {"line": 0, "character": 0},
                        "end": {"line": line, "character": character},
                    }
                    new_text = "int64 neat = 1\n"
                send({"jsonrpc": "2.0", "id": message.get("id"), "result": [
                    {"range": edit_range, "newText": new_text}
                ]})
                continue
            if "id" in message and message.get("id") is not None:
                send({"jsonrpc": "2.0", "id": message.get("id"),
                      "error": {"code": -32601, "message": "method not found"}})


if __name__ == "__main__":
    raise SystemExit(main())
