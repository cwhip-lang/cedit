"""Format the current buffer through a stand-in language server.

The stand-in speaks the formatting requests from cwhip-lsp. This test does
not run the installed cwhip-lsp binary.
"""

import argparse
import json
import sys
from pathlib import Path
import tempfile

from gtk_support import headless
from program_runner import environment, invoke


DRIVER = r"""
class FormatChecks {
    public:
    Cedit editor
    int64 stage
    int64 checks
    int64 waits
    void<> stepAction
    String supportCommand
    String unsupportedCommand
    String rejectCommand
    String supportLog
    String unsupportedLog
    String rejectLog
    String original
    String formatted
    String ranged
    void require(bool condition, String label) {
        if (!condition) {
            System.StandardIO().writeErrorLine(format(
                    "FAIL stage {}: {}: {}",
                    stage, label, editor.status.text()))
            System.Process().exit(1)
        }
        checks = checks + 1
    }
    String path(String name) {
        return(System.FileSystem().join(System.FileSystem().getCwd(), name))
    }
    String readLog(String logPath) {
        System.File file = System.File(logPath, "r")
        require(file.isOpen(), format("read {}", logPath))
        String text = file.readAll()
        file.close()
        return(text)
    }
    String requestLine(String log, String method) {
        String needle = format("\"method\":\"{}\"", method)
        list lines = log.split("\n")
        int64 index = 0
        while (index < lines.length) {
            String line = lines[index] as String
            if (line.contains(needle)) {
                return(line)
            }
            index = index + 1
        }
        return("")
    }
    void begin() {
        original = "alpha beta\ngamma delta\n"
        formatted = "int64 neat = 1\n"
        ranged = "alpha beta\nGAMMA delta\n"
        editor.activate()
        CommandBinding formatCommand = editor.settings.command("format")
        CommandBinding selectionCommand = editor.settings.command(
                "format-selection")
        require(formatCommand != null && formatCommand.name.equals(
                "Format document"), "format command")
        require(formatCommand.trigger.equals(""), "format has no shortcut")
        require(selectionCommand != null && selectionCommand.name.equals(
                "Format selection"), "format-selection command")
        require(selectionCommand.trigger.equals(""),
                "format-selection has no shortcut")
        require(editor.formatItem != 0 && editor.formatSelectionItem != 0,
                "format menu items")
        editor.openFile(path("sample.cw"))
        require(editor.currentDocument().view.text().equals(original),
                "opened sample")
        editor.formatSelection()
        require(editor.currentDocument().view.text().equals(original),
                "no selection leaves the buffer")
        require(editor.status.text().equals("No selection to format"),
                "no selection is reported")
        stage = 0
        waits = 0
        Gtk.Application().schedule(50, stepAction)
    }
    void step() {
        waits = waits + 1
        if (waits > 200) {
            require(false, "timed out waiting for the language server")
        }
        EditorDocument document = editor.currentDocument()
        if (stage == 0) {
            if (editor.client == null || !editor.client.ready) {
                Gtk.Application().schedule(50, stepAction)
                return
            }
            require(editor.client.canFormat && editor.client.canRangeFormat,
                    "server advertises formatting")
            editor.menu.activateItem(editor.formatItem)
            stage = 1
            waits = 0
        }
        else(stage == 1) {
            if (!document.view.text().equals(formatted)) {
                Gtk.Application().schedule(50, stepAction)
                return
            }
            require(editor.status.text().equals("Formatted"),
                    "document format status")
            String log = readLog(supportLog)
            String request = requestLine(log, "textDocument/formatting")
            require(request.contains("sample.cw"), request)
            require(request.contains("\"tabSize\":4"), request)
            require(request.contains("\"insertSpaces\":true"), request)
            require(!request.contains("\"range\""), request)
            document.view.undo()
            require(document.view.text().equals(original),
                    "undo restores the buffer")
            document.view.selectRange(2, 1, 2, 6)
            editor.updateSelectionActions()
            editor.menu.activateItem(editor.formatSelectionItem)
            stage = 2
            waits = 0
        }
        else(stage == 2) {
            if (!document.view.text().equals(ranged)) {
                Gtk.Application().schedule(50, stepAction)
                return
            }
            String log = readLog(supportLog)
            String request = requestLine(log, "textDocument/rangeFormatting")
            require(request.contains(
                    "\"start\":{\"line\":1,\"character\":0}"), request)
            require(request.contains(
                    "\"end\":{\"line\":1,\"character\":5}"), request)
            editor.client.launch(unsupportedCommand)
            stage = 3
            waits = 0
        }
        else(stage == 3) {
            if (editor.client == null || !editor.client.ready) {
                Gtk.Application().schedule(50, stepAction)
                return
            }
            require(!editor.client.canFormat && !editor.client.canRangeFormat,
                    "unsupported server advertises no formatting")
            document.view.setText(original)
            editor.formatDocument()
            require(document.view.text().equals(original),
                    "unsupported server leaves the buffer")
            require(editor.status.text().equals(
                    "Language server does not support formatting"),
                    "unsupported server is reported")
            String log = readLog(unsupportedLog)
            require(requestLine(log, "textDocument/formatting").equals(""),
                    "unsupported server is not asked to format")
            editor.client.launch(rejectCommand)
            stage = 4
            waits = 0
        }
        else(stage == 4) {
            if (editor.client == null || !editor.client.ready) {
                Gtk.Application().schedule(50, stepAction)
                return
            }
            document.view.setText(original)
            editor.formatDocument()
            stage = 5
            waits = 0
        }
        else {
            if (!editor.status.text().equals(
                    "Language server format failed: method not found")) {
                Gtk.Application().schedule(50, stepAction)
                return
            }
            require(document.view.text().equals(original),
                    "rejected format leaves the buffer")
            String log = readLog(rejectLog)
            require(!requestLine(log, "textDocument/formatting").equals(""),
                    "rejected server was asked to format")
            print(format("PASS format {}", checks))
            Gtk.Application().quit()
            return
        }
        Gtk.Application().schedule(50, stepAction)
    }
}
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--xvfb", required=True)
    parser.add_argument("--clang")
    parser.add_argument("--include")
    parser.add_argument("--native")
    args = parser.parse_args()
    args.work.mkdir(parents=True, exist_ok=True)
    server = Path(__file__).with_name("lsp_format_server.py").resolve()
    with tempfile.TemporaryDirectory(dir=args.work, prefix="format-") as directory:
        work = Path(directory).resolve()
        env = environment(work)
        config = Path(env["XDG_CONFIG_HOME"]) / "cwhip"
        config.mkdir()
        log_support = work / "support.log"
        log_unsupported = work / "unsupported.log"
        log_reject = work / "reject.log"
        commands = {
            "__SUPPORT__": f"{sys.executable} {server} support {log_support}",
            "__UNSUPPORTED__": (
                f"{sys.executable} {server} unsupported {log_unsupported}"),
            "__REJECT__": f"{sys.executable} {server} reject {log_reject}",
        }
        (config / "settings.toml").write_text(
            "version = 1\n[editor]\nlsp_command = "
            + json.dumps(commands["__SUPPORT__"]) + "\n")
        (work / "sample.cw").write_text("alpha beta\ngamma delta\n")
        text = args.source.read_text()
        index = text.rindex("\nstart {")
        setup = text[index:].replace(
            "app.onActivate(editor.activate)",
            "FormatChecks checks = FormatChecks()\n"
            "    checks.editor = editor\n"
            "    checks.stepAction = checks.step\n"
            "    checks.supportCommand = \"__SUPPORT__\"\n"
            "    checks.unsupportedCommand = \"__UNSUPPORTED__\"\n"
            "    checks.rejectCommand = \"__REJECT__\"\n"
            "    checks.supportLog = \"__LOG_SUPPORT__\"\n"
            "    checks.unsupportedLog = \"__LOG_UNSUPPORTED__\"\n"
            "    checks.rejectLog = \"__LOG_REJECT__\"\n"
            "    app.onActivate(checks.begin)")
        for token, value in {
                **commands,
                "__LOG_SUPPORT__": str(log_support),
                "__LOG_UNSUPPORTED__": str(log_unsupported),
                "__LOG_REJECT__": str(log_reject),
        }.items():
            setup = setup.replace(token, value)
        source = work / "format.cw"
        source.write_text(text[:index] + DRIVER + setup)
        for extra in args.source.parent.glob("*.cw"):
            if extra.name != args.source.name:
                (work / extra.name).write_text(extra.read_text())
        executable = work / "format"
        result = invoke([str(args.compiler.resolve()), str(source), "-o",
                         str(executable)], work, env, timeout=120)
        assert result.returncode == 0, result.stderr
        with headless(args.xvfb, work, env) as gui_env:
            result = invoke([str(executable)], work, gui_env, timeout=90)
        assert result.returncode == 0, result
        passed = [line for line in result.stdout.splitlines() if line.startswith("PASS ")]
        assert passed == ["PASS format 27"], result
        stderr = "\n".join(
            line for line in result.stderr.splitlines()
            if not line.startswith("libEGL warning:"))
        assert not stderr, stderr
        print(passed[0])


if __name__ == "__main__":
    main()
