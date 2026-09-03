import QtQuick
import qs.Commons
import "." as Flea
import "js/Keymap.js" as Keymap
import "js/Menu.js" as Menu

// A plain overlay, not a QQC Popup: the one Controls import cost 10 ms of warm startup.
Item {
    id: root

    // Fires with the row's own action string ("open", "trash"); a chosen Taildrop peer fires
    // "taildrop:<peerId>" instead, so one signal covers both without a second wire. The header's
    // rows fire "col:<key>" and "toggleHidden", routed in ui/Pane.qml's onChosen.
    signal chosen(string action)

    property bool opened: false
    // Driven from ui/Pane.qml's own state, so this file owns no hidden-file logic itself.
    property bool showHidden: false
    // [{id, label}], the reachable Taildrop targets; empty self-hides the whole row, see ui/Taildrop.qml.
    property var taildropPeers: []
    // The archive formats this box actually probed, and whether a converter is installed at all.
    property var archiveFormats: []
    property bool canConvert: false
    // Whether the cursor row is an archive, and whether it is an image; both decided client-side.
    property bool rowIsArchive: false
    property bool rowIsImage: false
    // Empty until the stock Dropbox service is installed and authenticated, which is what gates the row.
    property string dropboxPath: ""
    // True when the cursor row already lives under ~/Dropbox, where a share link is the useful action.
    property bool rowInDropbox: false
    // False on a listing's empty space, where only the two rows that need no row make sense.
    property bool hasRow: true

    // The rows the open menu offers, SNAPSHOTTED when it opens: a live binding rebuilds under the
    // pointer, destroys the pressed row mid-tap (the click falls through to the listing beneath and
    // moves the selection) and swaps a flyout's model to a collapsed frame — the rail handed its
    // rows in once since always, which is why the rail never had either bug. One instance serves
    // all three faces: a second one takes the keyboard from the list, see AGENTS.md.
    property var heldEntries: []
    readonly property var entries: root.heldEntries
    property bool forRail: false
    // Names the rail row the handed-in rows belong to, see ui/js/Mounts.js "railKey".
    property string railKey: ""
    signal railChosen(string action, string key)

    property bool forHeader: false
    function openForHeader(scenePoint) {
        root.forRail = false
        root.forHeader = true
        root.heldEntries = root.buildEntries()
        root.place(scenePoint)
    }

    // The pane keeps its Keys handler on the list, so the menu has to hand focus back on close.
    property Item focusHolder: null

    // The keyboard-highlighted top-level row, and which row's flyout is open beside it, or -1.
    property int cursor: 0
    property int openSubmenuRow: -1
    property int submenuCursor: 0
    readonly property bool submenuOpen: root.openSubmenuRow >= 0
    // The glyph every open flyout row draws, read back so a test can name it without OCR.
    function submenuGlyphs() {
        if (!root.submenuOpen)
            return ""
        var mark = root.entries[root.openSubmenuRow].action === "taildrop" ? "server" : "archive"
        var out = []
        for (var i = 0; i < root.submenuEntries.length; i++)
            out.push(mark)
        return out.join("|")
    }

    // The entries the open flyout draws, which belong to the row that opened it.
    readonly property var submenuEntries: root.submenuOpen && root.entries[root.openSubmenuRow]
        ? root.entries[root.openSubmenuRow].submenu : []

    // The row list this menu currently offers; a test reads this back through shell.qml's IPC.
    function buildEntries() {
        // Which release a rail row offers is the rail's knowledge, not the listing's, so the rail
        // hands its rows in already built; see ui/js/Mounts.js "railMenu".
        if (root.forRail)
            return root.heldEntries
        if (root.forHeader)
            return Menu.headerEntries(ViewState.hiddenCols, root.showHidden, ViewState.foldersFirst)
        return Menu.listingEntries({
            showHidden: root.showHidden,
            hasRow: root.hasRow,
            rowInDropbox: root.rowInDropbox,
            dropboxPath: root.dropboxPath,
            taildropPeers: root.taildropPeers,
            archiveFormats: root.archiveFormats,
            rowIsArchive: root.rowIsArchive,
            rowIsImage: root.rowIsImage,
            canConvert: root.canConvert,
        })
    }

    // A separator is never the cursor, so both key steps and the opening cursor skip over one.
    function stepCursor(from, delta) {
        var i = from + delta
        while (i >= 0 && i < root.entries.length) {
            if (root.entries[i].separator !== true)
                return i
            i += delta
        }
        return from
    }

    function firstRow() {
        return root.entries.length > 0 && root.entries[0].separator === true ? root.stepCursor(0, 1) : 0
    }

    anchors.fill: parent
    visible: root.opened
    z: 1

    // Takes a point in scene coordinates and keeps the whole menu inside the pane it belongs to.
    function openAt(scenePoint) {
        root.heldEntries = root.buildEntries()
        root.forRail = false
        root.forHeader = false
        root.railKey = ""
        root.place(scenePoint)
    }

    // ui/Sidebar.qml's own entrance to this same menu: the rail hands in its rows and the key that
    // names the row they came from, and a rail row with nothing to release opens no menu at all.
    function openForRail(key, entries, scenePoint) {
        if (!entries || entries.length === 0)
            return
        root.railKey = key
        root.forRail = true
        root.heldEntries = entries
        root.place(scenePoint)
    }

    // Cleared on both ends: a rail entry left standing would put Eject on a listing row's menu.
    function clearRail() {
        root.forRail = false
        root.railKey = ""
        root.heldEntries = []
        root.forHeader = false
    }

    // Where the menu was asked to open, in this item's own coordinates; clampFrame runs twice on it.
    property real placeX: 0
    property real placeY: 0

    // A Column hands its implicitHeight to the frame one polish after its model changes, so the
    // height place() reads is still the menu that was open before this one. Clamping again on the
    // real height lands before the first paint, so no menu is placed against another's size.
    function clampFrame() {
        frame.x = Menu.clamp(root.placeX, frame.width, root.width)
        frame.y = Menu.clamp(root.placeY, frame.height, root.height)
    }

    function place(scenePoint) {
        var point = root.mapFromItem(null, scenePoint)
        root.placeX = point.x
        root.placeY = point.y
        root.clampFrame()
        root.cursor = root.firstRow()
        root.openSubmenuRow = -1
        root.submenuCursor = 0
        root.focusHolder = root.focusedSibling()
        root.opened = true
        keyCatcher.forceActiveFocus()
    }

    // Whichever sibling holds active focus when the menu opens, which is the pane's list today.
    function focusedSibling() {
        var siblings = root.parent ? root.parent.children : []
        for (var i = 0; i < siblings.length; i++) {
            if (siblings[i] !== root && siblings[i].activeFocus)
                return siblings[i]
        }
        return null
    }

    // Every wheel scroll calls this, so a shut menu costs nothing and never touches focus.
    function close() {
        if (!root.opened)
            return
        root.opened = false
        root.openSubmenuRow = -1
        root.clearRail()
        if (root.focusHolder)
            root.focusHolder.forceActiveFocus()
    }

    // The menu closes before the action runs, so it never hangs over the listing that action opened.
    function choose(action) {
        // Both read before close(), which is what clears them.
        var key = root.railKey
        var rail = root.forRail
        root.close()
        if (rail) {
            root.railChosen(action, key)
            return
        }
        root.chosen(action)
    }

    // A row with its own action fires it as named; a peer or format composes the parent verb + id.
    function chooseSub(sub) {
        var entry = root.entries[root.openSubmenuRow]
        root.close()
        if (!entry)
            return
        if (sub.action !== undefined && sub.action.length > 0)
            root.chosen(sub.action)
        else
            root.chosen(entry.action + ":" + sub.id)
    }

    function openSubmenu(index) {
        root.openSubmenuRow = index
        root.submenuCursor = 0
    }

    // Rows above the open one are a mix of full rows and separators, so the offset is summed, not multiplied.
    function submenuOffset() {
        var y = 0
        for (var i = 0; i < root.openSubmenuRow; i++)
            y += root.entries[i].separator === true ? separatorProbe.separatorHeight : Theme.rowHeight
        return y
    }

    // One row off the model, only so the two heights above are read from MenuRow rather than repeated here.
    Flea.MenuRow {
        id: separatorProbe
        visible: false
        entry: ({ separator: true })
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.close()
    }

    // Declared before both frames so neither ring can darken the panel beside it; the canvas draws
    // this shadow under the menu and under the flyout alike.
    Flea.Shadow {
        surface: frame
    }

    Flea.Shadow {
        surface: flyout
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        onWheel: function (wheel) { wheel.accepted = true }
        z: 1
    }

    Rectangle {
        id: frame
        width: Theme.menuWidth
        // The vertical inset keeps the first and last row's square highlight off the rounded corners.
        height: rows.implicitHeight + 2 * Theme.spacing.rowPaddingY
        // The height this menu is actually going to have, arriving after place() has already run.
        onHeightChanged: if (root.opened) root.clampFrame()
        color: Theme.color.surface
        border.width: Theme.spacing.hairline
        border.color: Theme.color.muted
        // Mirrors hyprland decoration:rounding, same as NetworkDialog; 0 on a stock box stays square.
        radius: Style.cornerRadius

        Column {
            id: rows
            width: parent.width
            y: Theme.spacing.rowPaddingY

            Repeater {
                model: root.entries
                delegate: Flea.MenuRow {
                    id: row
                    required property var modelData
                    required property int index
                    width: rows.width
                    entry: row.modelData
                    compact: root.forRail
                    current: !root.submenuOpen && root.cursor === row.index
                    onHoverEntered: root.cursor = row.index
                    onActivated: {
                        if (Menu.hasSubmenu(row.modelData))
                            root.openSubmenu(row.index)
                        else
                            root.choose(row.modelData.action)
                    }
                }
            }
        }
    }

    // The flyout: a second frame beside whichever row opened it, only while one has.
    Rectangle {
        id: flyout
        visible: root.submenuOpen
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            hoverEnabled: true
            onWheel: function (wheel) { wheel.accepted = true }
        }
        x: frame.x + frame.width
        // peers.y already carries the inset, so the flyout frame itself stays on the row grid.
        // A flyout near the bottom drops up: clamped against the pane, a row of air to spare.
        y: Menu.clamp(frame.y + root.submenuOffset(), height + Theme.spacing.rowPaddingY, parent.height)
        width: Theme.menuWidth
        height: peers.implicitHeight + 2 * Theme.spacing.rowPaddingY
        color: Theme.color.surface
        border.width: Theme.spacing.hairline
        border.color: Theme.color.muted
        radius: Style.cornerRadius

        Column {
            id: peers
            width: parent.width
            y: Theme.spacing.rowPaddingY

            Repeater {
                model: root.submenuEntries
                delegate: Flea.MenuRow {
                    id: subRow
                    required property var modelData
                    required property int index
                    width: peers.width
                    // A Taildrop peer is a machine and takes the sidebar's own server mark; an archive
                    // format is a file about to exist and takes the archive mark.
                    // A row with its own whole action (the Advanced group) fires it directly; a
                    // Taildrop peer or an archive format composes the parent verb with its id.
                    entry: ({ label: subRow.modelData.label, action: "",
                              glyph: subRow.modelData.glyph !== undefined ? subRow.modelData.glyph
                                    : root.entries[root.openSubmenuRow].action === "taildrop" ? "server" : "archive" })
                    current: root.submenuCursor === subRow.index
                    onHoverEntered: root.submenuCursor = subRow.index
                    onActivated: root.chooseSub(subRow.modelData)
                }
            }
        }
    }

    // One focus catcher for the whole menu: real QML focus never moves into the Repeater rows
    // themselves, so every key lands here regardless of which level is open. They arrive through
    // keys.toml's own table, so j and k step this list the way they step every other one.
    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.onPressed: function (event) {
            var action = Keymap.lookup(event.key, event.text, event.modifiers)
            if (action === "escape") {
                if (root.submenuOpen)
                    root.openSubmenuRow = -1
                else
                    root.close()
                event.accepted = true
                return
            }
            if (action === "cursorDown") {
                if (root.submenuOpen)
                    root.submenuCursor = Math.min(root.submenuEntries.length - 1, root.submenuCursor + 1)
                else
                    root.cursor = root.stepCursor(root.cursor, 1)
                event.accepted = true
                return
            }
            if (action === "cursorUp") {
                if (root.submenuOpen)
                    root.submenuCursor = Math.max(0, root.submenuCursor - 1)
                else
                    root.cursor = root.stepCursor(root.cursor, -1)
                event.accepted = true
                return
            }
            // Right and Enter and Space all choose; Right on a shut flyout opens it, Left shuts it.
            if (action === "open" || action === "preview" || action === "seekForward") {
                if (root.submenuOpen) {
                    var sub = root.submenuEntries[root.submenuCursor]
                    if (sub)
                        root.chooseSub(sub)
                } else {
                    var entry = root.entries[root.cursor]
                    if (Menu.hasSubmenu(entry))
                        root.openSubmenu(root.cursor)
                    else if (entry && entry.separator !== true)
                        root.choose(entry.action)
                }
                event.accepted = true
            }
            if ((action === "seekBack" || action === "cursorLeft") && root.submenuOpen) { root.openSubmenuRow = -1; event.accepted = true; return }
        }
    }
}
