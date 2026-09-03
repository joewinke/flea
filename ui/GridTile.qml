import QtQuick
import qs.Commons
import "." as Flea
import "js/Format.js" as Format
import "js/Icons.js" as Icons

// One grid cell: the same mark the list row draws, in a larger slot, with the name under it.
Item {
    id: root

    property var row: null
    property bool cursor: false
    property bool hovered: false
    property bool selected: false
    property string thumb: ""

    // A lifted tile is the cursor, the pointer or a selection member, the same ladder Row.qml climbs.
    readonly property bool lifted: root.cursor || root.hovered || root.selected
    // A thumbnail path is not a thumbnail: the cache file can be evicted between the pane's answer
    // and the decode, and a tile whose Image failed to load has to be marked by its kind instead.
    readonly property bool thumbDrawn: root.thumb.length > 0 && tileThumb.status !== Image.Error

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.spacing.hairline
        color: root.cursor ? Style.selectedFill
             : root.selected ? Style.selectionFill
             : root.hovered ? Style.hoverFill
             : "transparent"
        // The canvas outlines the picked tile as well as filling it, because a tile has no row edge to read.
        border.width: root.selected || root.cursor ? Theme.spacing.hairline : 0
        border.color: Theme.color.accent
    }

    Item {
        id: markSlot
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.spacing.rowPaddingX
        width: Theme.grid.iconSize
        height: Theme.grid.iconSize

        // A thumbnail is a decoded image and stays one; the glyph beside it is a native mark, and
        // exactly one is visible, chosen the same way ui/Row.qml chooses.
        Image {
            id: tileThumb
            anchors.fill: parent
            visible: root.thumbDrawn
            // Format.fileUri, not a concatenation: a cache path can carry a # or a ? and either one
            // silently truncates a plain file:// URL, which is what the hashcache fixture proves.
            source: root.thumb.length > 0 ? Format.fileUri(root.thumb) : ""
            fillMode: Image.PreserveAspectFit
            sourceSize.width: Theme.grid.iconSize
            sourceSize.height: Theme.grid.iconSize
            asynchronous: true
            cache: false
        }

        Flea.Glyph {
            anchors.fill: parent
            visible: !root.thumbDrawn
            name: root.row ? Icons.glyphFor(root.row.i) : "file"
            color: root.cursor || root.selected ? Theme.color.accent : Theme.color.muted
        }
    }

    // corner: a filename is arbitrary text, so PlainText, the same rule every name on this surface follows.
    Text {
        anchors.top: markSlot.bottom
        anchors.topMargin: Theme.spacing.gap
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.spacing.gap
        anchors.rightMargin: Theme.spacing.gap
        horizontalAlignment: Text.AlignHCenter
        text: root.row ? root.row.n : ""
        color: root.cursor || root.selected ? Theme.color.accent : Theme.color.foreground
        font.family: Theme.font.family
        font.pixelSize: Theme.font.caption
        textFormat: Text.PlainText
        elide: Text.ElideRight
    }
}
