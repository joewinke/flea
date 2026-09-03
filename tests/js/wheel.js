.import "../../ui/js/Wheel.js" as Wheel

// The wheel's modifier map, shared by the list's view and the rail, so the same gesture cannot
// mean two things depending on which surface it landed over. See ui/js/Wheel.js.

function run(check) {
    check("the plain wheel is the viewport's", Wheel.meaning(Qt.NoModifier), "viewport")
    check("alt steps the cursor", Wheel.meaning(Qt.AltModifier), "cursor")
    check("ctrl jumps to an end", Wheel.meaning(Qt.ControlModifier), "end")
    check("shift extends the selection", Wheel.meaning(Qt.ShiftModifier), "extend")

    // A wheel can carry two modifiers at once when a chord is held through the scroll; the map
    // answers with the strongest verb rather than leaving the pair undefined.
    check("ctrl outranks alt", Wheel.meaning(Qt.ControlModifier | Qt.AltModifier), "end")
    check("ctrl outranks shift", Wheel.meaning(Qt.ControlModifier | Qt.ShiftModifier), "end")
    check("alt outranks shift", Wheel.meaning(Qt.AltModifier | Qt.ShiftModifier), "cursor")

    // A step clamps to the run it steps through, so a chord held at either end sits still.
    check("a step clamps at the top", Wheel.stepped(0, -1, 5), 0)
    check("a step clamps at the bottom", Wheel.stepped(4, 1, 5), 4)
    check("a step moves within the run", Wheel.stepped(2, 1, 5), 3)

    // The end a Ctrl wheel lands on, wheel-down being the last row and wheel-up the first.
    check("ctrl down lands on the last row", Wheel.end(1, 5), 4)
    check("ctrl up lands on the first", Wheel.end(-1, 5), 0)

    // Direction as the item order reads it: raw axis inverted by a natural-scroll setup, and the
    // event's inverted flag restoring the physical turn the hand made.
    check("a raw wheel-down is the next row", Wheel.direction(-120, false), 1)
    check("a raw wheel-up is the previous row", Wheel.direction(120, false), -1)
    check("an inverted wheel-down still steps to the next row", Wheel.direction(120, true), 1)
    check("an inverted wheel-up still steps to the previous row", Wheel.direction(-120, true), -1)
}
