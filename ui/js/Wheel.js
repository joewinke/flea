.pragma library

// What a wheel gesture means, shared by the list's view and the rail. The plain wheel is the
// viewport's own verb everywhere: the list's ListView pans and its cursor follows in List.qml's
// contentY handler, the rail's Flickable pans and nothing chases the cursor back. Only the
// modified chords reach the item level, and the same modifier has to mean the same thing over
// both surfaces or the split between them is a bug neither file can see.

// Ctrl jumps to either end, g/G's verb; Alt steps the cursor one row a notch, j/k's verb; Shift
// extends the selection the way Shift+Up/Down do. Control wins when it arrives beside another
// modifier, and anything else — the plain wheel included — is a viewport pan the Flickable keeps.
function meaning(modifiers) {
    if (modifiers & Qt.ControlModifier)
        return "end"
    if (modifiers & Qt.AltModifier)
        return "cursor"
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
