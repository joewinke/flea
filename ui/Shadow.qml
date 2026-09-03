import QtQuick
import qs.Commons
import "js/Shadow.js" as ShadowMath

// The canvas's drop shadow under a floating in-app surface, drawn as stacked rounded rings rather
// than a blur: MultiEffect wants an offscreen render target and a downsample pyramid behind every
// surface it touches, and that is GPU memory, which PSS cannot see on a product judged on PSS.
// Declare it immediately before the surface it belongs to, in the same parent, and it takes its
// stacking from that: Shadow { surface: card } sits above whatever was declared before it.
Item {
    id: root

    // The Item this sits behind. Anchors reach a sibling or a parent and no further, so it has to be
    // declared in the same parent as the surface it names.
    // corner: var and not Item, because ui/NetworkDialog.qml's card is a qs.Ui BorderSurface, whose
    // type the linter cannot resolve at all, so an Item-typed property reads that one assignment as
    // a type error while the plain Rectangles at the other three call sites pass.
    required property var surface

    anchors.fill: root.surface
    // A surface that hides or fades takes its own shadow with it; the menu flyout does the first and
    // every dialog card does the second.
    visible: root.surface.visible
    opacity: root.surface.opacity

    Repeater {
        model: Theme.shadow.steps

        delegate: Rectangle {
            id: ring

            required property int index
            readonly property int growth: ShadowMath.growth(Theme.shadow.spread, Theme.shadow.steps, ring.index)

            anchors.fill: parent
            anchors.leftMargin: -ring.growth
            anchors.rightMargin: -ring.growth
            // A negative top margin grows the ring upward and a negative bottom margin grows it
            // downward, so the offset adds to one and subtracts from the other to move it down.
            anchors.topMargin: Theme.shadow.offset - ring.growth
            anchors.bottomMargin: -Theme.shadow.offset - ring.growth
            color: Theme.shadow.color
            // Concentric with the surface's own corner, which is Style.cornerRadius at every caller.
            radius: ShadowMath.ringRadius(Style.cornerRadius, ring.growth)
        }
    }
}
