import QtQuick
import qs.Commons

// A text row with a hairline frame, not filled button chrome: the canvas draws every dialog button
// this way, and the accent one is the action the dialog is for.
Item {
    id: root

    property string label: ""
    property bool primary: false

    signal activated()

    readonly property color ink: root.primary ? Theme.color.accent : Theme.color.muted

    implicitWidth: text.implicitWidth + 2 * Theme.spacing.gap + 2 * Theme.spacing.hairline
    implicitHeight: text.implicitHeight + Theme.spacing.gap + 2 * Theme.spacing.hairline

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: Theme.spacing.hairline
        border.color: root.ink
    }

    Text {
        id: text
        anchors.centerIn: parent
        text: root.label
        color: root.ink
        font.family: Theme.font.family
        font.pixelSize: Theme.font.bodySmall
        textFormat: Text.PlainText
    }

    HoverHandler { cursorShape: Qt.PointingHandCursor }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: root.activated()
    }
}
