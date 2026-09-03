.pragma library

// What a wheel gesture means, shared by the list's view and the rail. The plain wheel is the
// viewport's own verb everywhere: the list's ListView pans and its cursor follows in List.qml's
// contentY handler, the rail's Flickable pans and nothing chases the cursor back. Only the
// modified chords reach the item level, and the same modifier has to mean the same thing over
// both surfaces or the split between them is a bug neither file can see.

// Ctrl steps the cursor one row a notch, j/k's verb; Alt jumps to either end, g/G's verb; Shift
// extends the selection the way Shift+Up/Down do. Control wins when it arrives beside another
// modifier, and anything else — the plain wheel included — is a viewport pan the Flickable keeps.
// The two chords are written against the modifier Qt names, and this operator's input stack
// swaps them: a synthetic Alt arrives carrying ControlModifier and a synthetic Ctrl carrying
// AltModifier, read back off the event's own modifiers field, so the stepper rides the modifier
// the hand's Alt key actually delivers and the jumper the one Ctrl does.
function meaning(modifiers) {
    if (modifiers & Qt.ControlModifier)
        return "cursor"
    if (modifiers & Qt.AltModifier)
        return "end"
    if (modifiers & Qt.ShiftModifier)
        return "extend"
    return "viewport"
}

// The index a step lands on, clamped to the run. dir is +1 for a wheel-down, the direction the
// content moves, which is the direction the cursor steps in both surfaces.
function stepped(index, dir, count) {
    return Math.max(0, Math.min(count - 1, index + dir))
}

// The end a Ctrl wheel jumps to: the last row scrolling down, the first scrolling up.
function end(dir, count) {
    return dir > 0 ? count - 1 : 0
}

// The axis the event actually turned. Some input stacks deliver a modified wheel on the
// horizontal axis — this operator's rewrites Alt+vertical-wheel as horizontal before it reaches
// the app, modifiers intact — so a chord that reads only angleDelta.y sees zero and the verb
// runs one way whatever the hand did. Reading the axis that moved costs nothing and is correct
// for both the plain vertical wheel and the rewritten one.
function axisDelta(wheel) {
    return Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? wheel.angleDelta.x : wheel.angleDelta.y
}

// The wheel's direction as the item order reads it: a wheel-down steps to the next row, whatever
// the user's scrolling convention is. A natural-scroll setup inverts the axis before the event
// arrives, so the raw sign says up when the hand rolled down, and the event's own inverted flag
// is what restores the physical direction. Both surfaces read this, so the same wheel turn steps
// the same way over the list and the rail.
function direction(angleDeltaY, inverted) {
    var dir = angleDeltaY < 0 ? 1 : -1
    return inverted ? -dir : dir
}
