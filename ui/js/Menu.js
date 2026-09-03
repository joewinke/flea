.pragma library

// The one definition of a submenu row, shared by ui/MenuRow.qml and ui/ContextMenu.qml. The two
// carried their own copies and drifted: the row drew no disclosure at all for want of this.

// A submenu row carries its flyout's own entries in this field, so the test is that the field is
// present, never that it is true.
function hasSubmenu(entry) {
    return entry !== undefined && entry !== null && entry.submenu !== undefined
}

// Where one edge of a menu frame sits when it opens at this point: far enough back that the whole
// frame stays inside its bounds, and never off the near edge. A frame larger than its bounds pins
// to the near edge and its far end is cut, which no menu built on this box reaches.
function clamp(point, size, bounds) {
    return Math.max(0, Math.min(bounds - size, point))
}
