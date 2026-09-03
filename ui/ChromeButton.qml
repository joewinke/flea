import QtQuick
import qs.Commons
import "." as Flea

// One glyph button in the window chrome: muted at rest, accent when it names the current view, and
// dimmed when there is nowhere for it to go.
Item {
    id: root

    property string glyph: "file"
    property bool active: false

    signal activated()

    // A control with nowhere to go still occupies its slot, so the bar never reflows as history changes.
    readonly property real disabledOpacity: 0.35

    // The mark is the chrome mark token and the hit area is the strip's whole height, so a click
    // lands anywhere in the 27 px band rather than only on the 16 px mark.
    implicitWidth: Theme.chromeMarkSize
    implicitHeight: Theme.chromeHeight

    Flea.Glyph {
        anchors.centerIn: parent
        width: Theme.chromeMarkSize
        height: Theme.chromeMarkSize
        name: root.glyph
        color: root.active ? Theme.color.accent : Theme.color.muted
        opacity: root.enabled ? 1 : root.disabledOpacity
    }

    // Item.enabled gates both handlers itself; a shadowing bool property here used to do it by hand.
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: root.activated()
    }
}
