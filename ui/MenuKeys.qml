import QtQuick
import qs.Commons
import "." as Flea
import "js/Keymap.js" as Keymap
import "js/Menu.js" as Menu

// One focus catcher for the whole menu: real QML focus never moves into the Repeater rows, so
// every key lands here at either level, through keys.toml's own table — j and k step the list.
Item {
    id: keyCatcher
    anchors.fill: parent
    focus: true

    Keys.onPressed: function (event) {
        var action = Keymap.lookup(event.key, event.text, event.modifiers)
        if (action === "escape") {
            if (menu.submenuOpen)
                menu.openSubmenuRow = -1
            else
                menu.close()
            event.accepted = true
            return
        }
        if (action === "cursorDown") {
            if (menu.submenuOpen)
                menu.submenuCursor = Math.min(menu.submenuEntries.length - 1, menu.submenuCursor + 1)
            else
                menu.cursor = menu.stepCursor(menu.cursor, 1)
            event.accepted = true
            return
        }
        if (action === "cursorUp") {
            if (menu.submenuOpen)
                menu.submenuCursor = Math.max(0, menu.submenuCursor - 1)
            else
                menu.cursor = menu.stepCursor(menu.cursor, -1)
            event.accepted = true
            return
        }
        // Right and Enter and Space all choose; Right on a shut flyout opens it, Left shuts it.
        if (action === "open" || action === "preview" || action === "seekForward") {
            if (menu.submenuOpen) {
                var sub = menu.submenuEntries[menu.submenuCursor]
                if (sub)
                    menu.chooseSub(sub)
            } else {
                var entry = menu.entries[menu.cursor]
                if (Menu.hasSubmenu(entry))
                    menu.openSubmenu(menu.cursor)
                else if (entry && entry.separator !== true)
                    menu.choose(entry.action)
            }
            event.accepted = true
        }
        if ((action === "seekBack" || action === "cursorLeft") && menu.submenuOpen) { menu.openSubmenuRow = -1; event.accepted = true; return }

