import QtQuick

// The listing's loading touch, EmptyState's sibling: the caller places it over listArea and
// gates visibility on listingState. The hold-off keeps a local listing, single-digit
// milliseconds on this box, from ever flashing the mark; only slow sources (network mounts,
// a cold spinning disk) live long enough to show it.
Item {
    id: root

    readonly property int holdOffMs: 150
    property bool armed: false

    // running binds to visibility rather than an onVisibleChanged handler: the pane starts life
    // in "loading", so visible is true at creation and a change handler would never fire.
    Timer {
        id: holdOff
        interval: root.holdOffMs
        running: root.visible
        onTriggered: root.armed = true
    }

    onVisibleChanged: if (!root.visible) root.armed = false

    Spinner {
        anchors.centerIn: parent
        // The same brand mark as EmptyState's hero, which States.dc.html draws at 48; two row heights was 74.
        width: Theme.heroMarkSize
        height: Theme.heroMarkSize
        visible: root.armed
    }
}
