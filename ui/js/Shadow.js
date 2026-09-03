.pragma library

// The arithmetic behind ui/Shadow.qml, kept in a library so a test can run it with no window.
// The canvas draws box-shadow: 0 16px 40px rgba(0,0,0,0.5) under every floating in-app surface.

// How far past the surface edge ring `index` sits, counting 0 as the outermost. CSS spreads a blur
// half inside the shape's edge and half outside, so the caller passes half the declared blur as the
// spread and the outermost ring takes all of it. Each ring inside takes one step less, which is what
// darkens the stack toward the surface the way the blur's own falloff does.
function growth(spread, steps, index) {
    if (!(steps > 0))
        return 0
    return Math.round(spread * (steps - index) / steps)
}

// The alpha one ring carries so the whole stack composites to `strength`. Solving for it here rather
// than writing three alphas down means changing the ring count changes only how smooth the falloff
// looks, never how dark the shadow ends up.
function stepAlpha(strength, steps) {
    if (!(steps > 0))
        return 0
    return 1 - Math.pow(1 - strength, 1 / steps)
}

// A ring's own corner, concentric with the surface's. A square surface has no corner to grow, and
// Style.cornerRadius is 0 on a stock Omarchy box, so rounding the rings there would leave the card's
// square corners poking out of a rounded shadow.
function ringRadius(cornerRadius, growth) {
    if (!(cornerRadius > 0))
        return 0
    return cornerRadius + growth
}
