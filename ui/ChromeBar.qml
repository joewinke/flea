import QtQuick
import qs.Commons
import "." as Flea
import "js/Format.js" as Format

// The window's top chrome, per the canvas: where you are on the left, how you are looking at it on
// the right. The path lives here rather than in the status bar, which the design gives to counts.
Item {
    id: root

    property string path: ""
    property string home: ""
    property bool canGoBack: false
    property bool canGoUp: false
    // "list", "columns" or "grid"; the button naming the current one takes the accent.
    property string viewMode: "list"

    signal backRequested()
    signal upRequested()
    signal searchRequested()
    signal viewChosen(string mode)

    // A path reads as the user writes it, so home comes back as a tilde; the leaf is the directory
    // you are actually in and takes full contrast, everything above it stays muted.
    readonly property string display: Format.tilde(root.path, root.home)

    // A chrome strip, not a data row; see Theme.qml's chromeHeight comment.
    implicitHeight: Theme.chromeHeight

    Rectangle {
        anchors.fill: parent
        color: Theme.color.surface
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: Theme.spacing.hairline
        color: Theme.color.foreground
        opacity: 0.12
    }

    // A test drives these by coordinate, because a glyph button carries no text to find on screen.
    function buttonFor(glyph) {
        var groups = [nav, views]
        for (var g = 0; g < groups.length; g++) {
            var kids = groups[g].children
            for (var i = 0; i < kids.length; i++) {
                if (kids[i].glyph === glyph)
                    return kids[i]
            }
        }
        return null
    }

    Row {
        id: nav
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacing.rowPaddingX
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing.gap

        Flea.ChromeButton {
            glyph: "arrow-left"
            enabled: root.canGoBack
            onActivated: root.backRequested()
        }

        Flea.ChromeButton {
            glyph: "arrow-up"
            enabled: root.canGoUp
            onActivated: root.upRequested()
        }
    }

    // corner: a path is arbitrary text, so PlainText, the same rule every filename on this surface follows.
    Text {
        id: pathText
        anchors.left: nav.right
        anchors.leftMargin: Theme.spacing.gap
        anchors.right: views.left
        anchors.rightMargin: Theme.spacing.gap
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.color.muted
        font.family: Theme.font.family
        font.pixelSize: Theme.font.caption
        textFormat: Text.PlainText
        // The tail identifies the directory, so a path too long for the bar elides from its left.
        elide: Text.ElideLeft
        text: Format.parentPart(root.display)
    }

    Text {
        id: leafText
        anchors.left: pathText.left
        anchors.leftMargin: Math.min(pathText.contentWidth, pathText.width)
        anchors.right: views.left
        anchors.rightMargin: Theme.spacing.gap
        anchors.verticalCenter: parent.verticalCenter
        text: Format.leafPart(root.display)
        color: Theme.color.foreground
        font.family: Theme.font.family
        font.pixelSize: Theme.font.caption
        textFormat: Text.PlainText
        elide: Text.ElideRight
    }

    Row {
        id: views
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacing.rowPaddingX
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing.gap

        Flea.ChromeButton {
            glyph: "search"
            onActivated: root.searchRequested()
        }

        Repeater {
            model: ["list", "columns", "grid"]
            delegate: Flea.ChromeButton {
                required property string modelData
                glyph: modelData
                active: root.viewMode === modelData
                onActivated: root.viewChosen(modelData)
            }
        }
    }
}
