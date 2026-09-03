pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The per-user view state that outlives a window: which list columns the user has hidden, and
// later whatever else a preference earns a toggle for. One JSON file under ~/.config/flea, read
// once at construction and rewritten on every change through the same FileView pattern the
// bookmarks use (ui/NetworkDialog.qml's write, ui/Sidebar.qml's watch). A write over a directory
// that does not exist yet is the one silent failure this singleton allows: the toggles keep
// working for the session and the state just does not outlive it.
QtObject {
    id: root

    // The list-column keys ("mode"/"size"/"date"/"kind") the user has hidden. Name is not here:
    // it is the one column a file manager cannot do without, see ui/js/Columns.js.
    property var hiddenCols: []

    // The backend's standing "dirs" answer (true is the shipped default): every list and sort this
    // session sends carries it, and the header menu's flip re-lists, which is toggleHidden's own
    // gesture for a state that changes what the listing shows.
    property bool foldersFirst: true
    // The rest of the workspace the user expects to come back: dotfiles, view mode later.
    property bool showHidden: false
    property string sortBy: "name"
    property bool sortDesc: false

    function toggleFoldersFirst() {
        root.foldersFirst = !root.foldersFirst
        save()
    }

    function save() {
        store.setText(JSON.stringify({ hiddenCols: root.hiddenCols, foldersFirst: root.foldersFirst,
                                       showHidden: root.showHidden, sortBy: root.sortBy, sortDesc: root.sortDesc }, null, 2) + "\n")
    }

    onFoldersFirstChanged: save()
    onShowHiddenChanged: save()
    onSortByChanged: save()
    onSortDescChanged: save()

    // Flipped by ui/Pane.qml's onChosen, when a header-menu row answers "col:<key>".
    function toggleColumn(key) {
        var next = []
        var had = false
        for (var i = 0; i < root.hiddenCols.length; i++) {
            if (root.hiddenCols[i] === key) {
                had = true
                continue
            }
            next.push(root.hiddenCols[i])
        }
        if (!had)
            next.push(key)
        root.hiddenCols = next
    }

    function load() {
        try {
            var parsed = JSON.parse(store.text())
            if (parsed && parsed.hiddenCols)
                root.hiddenCols = parsed.hiddenCols
            if (parsed && parsed.foldersFirst !== undefined)
                root.foldersFirst = parsed.foldersFirst
            if (parsed && parsed.showHidden !== undefined)
                root.showHidden = parsed.showHidden
            if (parsed && parsed.sortBy !== undefined)
                root.sortBy = parsed.sortBy
            if (parsed && parsed.sortDesc !== undefined)
                root.sortDesc = parsed.sortDesc
        } catch (e) {
            // A file another hand wrote is not this file's problem: the defaults stand.
        }
    }

    property var store: FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") && Quickshell.env("XDG_CONFIG_HOME").length > 0
               ? Quickshell.env("XDG_CONFIG_HOME") : Quickshell.env("HOME") + "/.config") + "/flea/view.json"
        watchChanges: false
        printErrors: false
        blockLoading: true
        onLoaded: root.load()
        // A missing file lands here on first run, and the write seeds it so the next start reads.
        onLoadFailed: root.save()
    }

}
