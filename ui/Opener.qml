import Quickshell
import Quickshell.Io
import QtQuick

// The one component that launches a foreign program, so the huge page corner has one owner; see AGENTS.md "Opening a file".
Item {
    id: root

    signal failed(string path)
    signal isDirectory(string path)

    // The status src/open.rs returns for a directory, which the caller navigates to instead.
    readonly property int isDirectoryStatus: 3

    property string current: ""

    // flea --open decides and exits in milliseconds, so one Process serves every open.
    function open(path) {
        if (child.running) {
            return
        }
        root.current = path
        child.command = [Quickshell.env("FLEA_BIN") || "flea", "--open", path]
        child.running = true
    }

    Process {
        id: child

        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0) {
                return
            }
            if (exitCode === root.isDirectoryStatus) {
                root.isDirectory(root.current)
                return
            }
            root.failed(root.current)
        }
    }

    // The application name xdg-open would resolve for a path, for the listing menu's Open row
    // ("Open" beside the resolved name in muted type, so the menu says what is about to run).
    // Empty means flea itself is the answer: a directory navigates, and an unresolved mime says
    // nothing worth reading. One Process serves every query, the way open() does.
    property string defaultAppName: ""

    function defaultAppFor(path) {
        if (resolver.running) {
            return
        }
        resolver.command = ["sh", "-c",
            'p="$1"; m=$(xdg-mime query filetype "$p" 2>/dev/null) || exit 0; '
            + '[ "$m" = "inode/directory" ] && exit 0; '
            + 'd=$(xdg-mime query default "$m" 2>/dev/null) || exit 0; [ -n "$d" ] || exit 0; '
            + 'for f in "${XDG_DATA_HOME:-$HOME/.local/share}/applications/$d"'
            + ' /usr/local/share/applications/$d /usr/share/applications/$d; do '
            + '[ -f "$f" ] || continue; sed -n "s/^Name=//p" "$f" | head -n 1; exit 0; done',
            "_", path]
        resolver.running = true
    }

    // The system clipboard, for the listing menu's Copy Path row. wl-copy reads the text on stdin,
    // so the one-liner hands it over; flea's own copy clipboard (Ops.clip) is a different thing
    // and must stay a different thing.
    function copyText(text) {
        if (copier.running) {
            return
        }
        copier.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", text]
        copier.running = true
    }

    Process {
        id: resolver

        stdout: SplitParser {
            onRead: function (data) {
                var name = ("" + data).trim()
                if (name.length > 0)
                    root.defaultAppName = name
            }
        }
    }

    Process {
        id: copier
    }

}