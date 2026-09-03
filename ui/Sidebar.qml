import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "js/Icons.js" as Icons
import "js/Mounts.js" as Mounts
import "js/Places.js" as Places
import "js/Wheel.js" as Wheel

// The rail is Favorites, Network and Devices, three groups sharing one flat cursor space and one
// row delegate, ui/SidebarRow.qml. Each group occupies a contiguous run of "entries" in that
// order, so railAct's plain index math in ui/js/Focus.js needs no change and no existing index
// moves. Each group's own sourcing and process management lives in its Service, ui/NetworkMounts.qml
// and ui/DeviceMounts.qml, the OEM pattern: this file only reads "entries" from them and renders.
Item {
    id: root

    property bool focused: false
    // ui/Pane.qml's one ui/ContextMenu.qml, handed in rather than built here: a second instance in
    // this tree took the keyboard away from the list, see ui/SidebarRow.qml's own note.
    property var menu: null
    property int cursorIndex: 0
    property var favoriteEntries: []
    readonly property var networkEntries: mounts.entries
    // A changed rail is a changed row under any open editor, so the rename is void: the poll rebinds
    // its delegates in place, and an editor left standing came up empty over a different share.
    onNetworkEntriesChanged: root.cancelRename()
    readonly property var deviceEntries: devices.entries
    readonly property var entries: root.favoriteEntries.concat(root.networkEntries).concat(root.deviceEntries)

    // Clamped on the aggregate, never on a group: reading root.entries from onDeviceEntriesChanged
    // forces the entries binding's own first evaluation, which fires networkEntriesChanged, which
    // re-enters clampCursor before entries has a value. That threw a TypeError once per launch.
    onEntriesChanged: root.clampCursor()

    function clampCursor() {
        root.cursorIndex = Math.max(0, Math.min(root.entries.length - 1, root.cursorIndex))
    }

    signal opened(string path)
    signal addRequested()
    signal message(string text, bool isError)
    // Bubbled straight from NetworkMounts; shell.qml opens ui/ShareBrowser.qml on this.
    signal sharesListed(string baseUri, string baseLabel, var names)

    // The entry index mid-rename, or -1; Network only, see startRename below. ui/SidebarRow.qml
    // reads this to swap its Text for the OEM TextField, and ui/Pane.qml reads it as its own
    // key guard while the field owns the keyboard.
    property int renamingIndex: -1
    // Fires once, on both commit and cancel, so ui/Pane.qml has one place to hand focus back.
    signal renameFinished()

    // Sized in characters, because a monospace makes that exact where a pixel constant would be an accident.
    readonly property int widthChars: 18
    implicitWidth: metrics.advanceWidth * root.widthChars + 2 * Style.spacing.rowPaddingX

    TextMetrics {
        id: metrics
        font.family: Theme.font.family
        font.pixelSize: Theme.font.bodySmall
        text: "0"
    }

    FileView {
        id: userDirsFile
        path: Quickshell.env("HOME") + "/.config/user-dirs.dirs"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.rebuild()
        onLoadFailed: root.rebuild()
    }

    FileView {
        id: bookmarksFile
        path: Quickshell.env("HOME") + "/.config/gtk-3.0/bookmarks"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.rebuild()
        onLoadFailed: root.rebuild()
    }

    // The context menu's own gate for the two Dropbox rows, read through here rather than reaching
    // into the rail's internals from the pane.
    readonly property bool dropboxReady: mounts.dropboxReady

    DeviceMounts {
        id: devices
        onOpened: function (path) { root.opened(path) }
        onMessage: function (text, isError) { root.message(text, isError) }
    }

    NetworkMounts {
        id: mounts
        bookmarksText: bookmarksFile.text()
        onOpened: function (path) { root.opened(path) }
        onMessage: function (text, isError) { root.message(text, isError) }
        onSharesListed: function (baseUri, baseLabel, names) { root.sharesListed(baseUri, baseLabel, names) }
        // The same race NetworkDialog.qml's own saved() exists for, see AGENTS.md "A FileView
        // write can race a reload fired the moment setText() is called": mounts.rename() already
        // blocked on waitForJob() before this fires, so the reload here reads the write it caused.
        onRenamed: root.reloadBookmarks()
    }

    // Home is always first and is not in either file, so it is prepended rather than parsed; the
    // merge and its first-position-wins rule are Places.favorites', which tests/js/places.js checks.
    function rebuild() {
        var home = Quickshell.env("HOME")
        root.favoriteEntries = Places.favorites(home, userDirsFile.text(), bookmarksFile.text(), Icons.sidebarGlyphFor)
    }

    // ui/NetworkDialog.qml writes this same file; a watch set up before its parent directory
    // existed never fires, so its own saved() signal drives this explicit reload instead.
    function reloadBookmarks() {
        bookmarksFile.reload()
    }

    // The rail has no ListView virtualization, so every row already exists; the same itemFor idiom
    // ui/Pane.qml uses for the list, so a test can find a rail row's on-screen box.
    function railItemFor(index) {
        if (index < root.favoriteEntries.length)
            return favRepeater.itemAt(index)
        var rest = index - root.favoriteEntries.length
        if (rest < root.networkEntries.length)
            return netRepeater.itemAt(rest)
        return devRepeater.itemAt(rest - root.networkEntries.length)
    }

    // A favourite's path is already real and opens directly; a network share or a removable volume
    // may need mounting first, which is its own Service's job.
    function activate(index) {
        root.cancelRename()
        root.cursorIndex = index
        if (index < root.favoriteEntries.length) {
            root.opened(root.favoriteEntries[index].path)
            return
        }
        var rest = index - root.favoriteEntries.length
        if (rest < root.networkEntries.length) {
            mounts.activate(rest)
            return
        }
        devices.activate(rest - root.networkEntries.length)
    }

    // Network only: neither a favourite nor a device has a bookmark line of its own shape for
    // Places.relabel to find, and a volume's label lives on the filesystem, not in a rail file.
    function startRename(index) {
        if (index < root.favoriteEntries.length)
            return
        if (index >= root.favoriteEntries.length + root.networkEntries.length)
            return
        root.renamingIndex = index
    }

    // The rail's own answer to ui/Pane.qml's renameEditor: the live editor row, or null.
    function renameEditor() {
        if (root.renamingIndex < 0)
            return null
        var item = netRepeater.itemAt(root.renamingIndex - root.favoriteEntries.length)
        return item && item.renaming ? item : null
    }

    function cancelRename() {
        if (root.renamingIndex < 0)
            return
        root.renamingIndex = -1
        root.renameFinished()
    }

    // An empty submitted name reverts rather than writing an empty label.
    function commitRename(index, name) {
        root.renamingIndex = -1
        root.renameFinished()
        var trimmed = String(name || "").trim()
        if (trimmed.length === 0)
            return
        var entry = root.networkEntries[index - root.favoriteEntries.length]
        if (!entry)
            return
        mounts.rename(entry.uri, trimmed)
    }

    // Every cursor move the rail has — keyboard, the wheel chords, the clamp — reveals its row;
    // a plain wheel pan deliberately does not chase the cursor back, the list's own split of the
    // two verbs.
    onCursorIndexChanged: revealCursor()

    function revealCursor() {
        var row = root.railItemFor(root.cursorIndex)
        if (!row)
            return
        var p = row.mapToItem(scroller.contentItem)
        if (p.y < scroller.contentY)
            scroller.contentY = p.y
        else if (p.y + row.height > scroller.contentY + scroller.height)
            scroller.contentY = p.y + row.height - scroller.height
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.color.surface
    }

    // The rail's viewport. The list's wheel verb is a pan and the rail's is now the same one, so
    // this is a Flickable and not the bare Column it was, which could not show a row below its
    // own height however many favourites and mounts stood in the file.
    Flickable {
        id: scroller
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: rail.height + 2 * Style.spacing.rowPaddingX
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: rail
            anchors.top: parent.top
            anchors.topMargin: Style.spacing.rowPaddingX
            anchors.left: parent.left
            anchors.right: parent.right

            Text {
                id: favHeading
                x: Style.spacing.rowPaddingX
                bottomPadding: Style.spacing.rowGap
                text: "FAVORITES"
                color: Theme.color.muted
                font.family: Theme.font.family
                font.pixelSize: Theme.font.caption
                font.letterSpacing: 1
            }

            Repeater {
                id: favRepeater
                model: root.favoriteEntries
                delegate: SidebarRow {
                    cursor: index === root.cursorIndex
                    focused: root.focused
                    onActivated: function (idx) { root.activate(idx) }
                    onMenuRequested: function (idx, pos) { root.openRailMenu(idx, pos) }
                }
            }

            // The OEM panel idiom's own group gap, not the tighter row-to-row rhythm rows keep inside a group.
            Item {
                visible: root.networkEntries.length > 0
                width: rail.width
                height: Style.spacing.panelGap
            }

            // Self-hides with its list below when gio, the bookmarks file and Dropbox all have nothing to say.
            Item {
                id: netHeadingRow
                visible: root.networkEntries.length > 0
                width: rail.width
                height: netHeading.implicitHeight + Style.spacing.rowGap

                Text {
                    id: netHeading
                    x: Style.spacing.rowPaddingX
                    text: "NETWORK"
                    color: Theme.color.muted
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.caption
                    font.letterSpacing: 1
                }

                // A hand-drawn plus, not a Text "+": at caption size the font glyph read as a Christian cross, not a plus. Sized off the heading's own font token.
                Glyph {
                    id: addMark
                    name: "plus"
                    color: Theme.color.muted
                    width: Theme.font.caption
                    height: Theme.font.caption
                    anchors.right: parent.right
                    anchors.rightMargin: Style.spacing.rowPaddingX
                    anchors.verticalCenter: netHeading.verticalCenter

                    TapHandler {
                        onTapped: root.addRequested()
                    }
                }
            }

            Repeater {
                id: netRepeater
                model: root.networkEntries
                delegate: SidebarRow {
                    cursor: (index + root.favoriteEntries.length) === root.cursorIndex
                    focused: root.focused
                    renaming: (index + root.favoriteEntries.length) === root.renamingIndex
                    onActivated: function (idx) { root.activate(idx + root.favoriteEntries.length) }
                    onMenuRequested: function (idx, pos) { root.openRailMenu(idx + root.favoriteEntries.length, pos) }
                    onRenameCommitted: function (idx, text) { root.commitRename(idx + root.favoriteEntries.length, text) }
                    onRenameCancelled: root.cancelRename()
                }
            }

            Item {
                visible: root.deviceEntries.length > 0
                width: rail.width
                height: Style.spacing.panelGap
            }

            // Self-hides with its list below on a box lsblk reports no disk for; there is no header
            // over an empty group. Unlike NETWORK it carries no add mark: nothing here is bookmarked.
            Text {
                id: devHeading
                visible: root.deviceEntries.length > 0
                x: Style.spacing.rowPaddingX
                bottomPadding: Style.spacing.rowGap
                text: "DEVICES"
                color: Theme.color.muted
                font.family: Theme.font.family
                font.pixelSize: Theme.font.caption
                font.letterSpacing: 1
            }

            Repeater {
                id: devRepeater
                model: root.deviceEntries
                delegate: SidebarRow {
                    cursor: (index + root.favoriteEntries.length + root.networkEntries.length) === root.cursorIndex
                    focused: root.focused
                    onActivated: function (idx) { root.activate(idx + root.favoriteEntries.length + root.networkEntries.length) }
                    onMenuRequested: function (idx, pos) { root.openRailMenu(idx + root.favoriteEntries.length + root.networkEntries.length, pos) }
                }
            }
        }
    }

    // The rail's modified wheel, routed by the map ui/js/Wheel.js keeps and the list reads too.
    // The plain wheel is not accepted here, so it falls through to the Flickable above and pans;
    // Shift is not accepted either, because rail rows carry no selection for an extend to land on.
    WheelHandler {
        acceptedModifiers: Qt.AltModifier | Qt.ControlModifier
        onWheel: function (wheel) {
            if (root.renamingIndex >= 0)
                return
            var dir = wheel.angleDelta.y < 0 ? 1 : -1
            if (Wheel.meaning(wheel.modifiers) === "end")
                root.cursorIndex = Wheel.end(dir, root.entries.length)
            else
                root.cursorIndex = Wheel.stepped(root.cursorIndex, dir, root.entries.length)
        }
    }

    // The one divider in the whole design.
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Style.spacing.hairline
        color: Theme.color.foreground
        opacity: 0.12
    }

    // Right click raises the menu over the row, which is the whole affordance: an eject that can
    // only be reached by right-clicking twice is one nobody can see. Which rows offer what lives in
    // ui/js/Mounts.js "railMenu", because a row with nothing to release must open no menu at all.
    function openRailMenu(index, scenePosition) {
        root.cancelRename()
        var entry = root.entries[index]
        if (!entry || !root.menu) {
            return
        }
        root.cursorIndex = index
        root.menu.openForRail(Mounts.railKey(entry), Mounts.railMenu(entry), scenePosition)
    }

    // The keyboard's own entrance to the same menu, opened under the row the rail cursor is on.
    // Whether that row has anything to release is ui/js/Focus.js "raiseMenu"'s question, already
    // answered before this is called; this only turns the cursor into a point to open at.
    function openCursorMenu() {
        var row = root.railItemFor(root.cursorIndex)
        if (!row)
            return
        root.openRailMenu(root.cursorIndex, row.mapToItem(null, Style.spacing.rowPaddingX, row.height))
    }

    Connections {
        target: root.menu
        // A chosen menu row arrives with the row's key rather than its position, the poll problem
        // Mounts.release's own comment carries; this only hands the choice to it.
        function onRailChosen(action, key) { Mounts.release(action, key, devices, mounts, root.deviceEntries, root.networkEntries) }
    }
}
