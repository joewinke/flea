.import "../../ui/js/Shadow.js" as Shadow

// ui/Shadow.qml draws the canvas's box-shadow as stacked rings because a MultiEffect blur allocates
// an offscreen render target per surface, and GPU memory is invisible to the PSS column Flea is
// judged on. These are the two numbers that decide where a ring sits and how dark it is, at the
// box's own tokens: spread 20 (half the canvas blur of 40) over 3 rings, reaching alpha 0.5.

function run(check) {
    // Ring 0 is the outermost and takes the whole spread, so the shadow reaches exactly as far past
    // the surface as CSS puts a 40 px blur: 20 px.
    check("the outermost ring reaches the whole spread",
          Shadow.growth(20, 3, 0), 20)
    check("the middle ring sits two thirds out",
          Shadow.growth(20, 3, 1), 13)
    check("the innermost ring sits one third out",
          Shadow.growth(20, 3, 2), 7)
    // Monotonic and never zero: a ring that collapsed onto the surface edge would draw a hard band.
    check("the rings step inward without ever reaching the surface edge",
          Shadow.growth(20, 3, 0) > Shadow.growth(20, 3, 1)
          && Shadow.growth(20, 3, 1) > Shadow.growth(20, 3, 2)
          && Shadow.growth(20, 3, 2) > 0, true)
    // A stock Omarchy box runs base-size 12, where space() is the identity and the canvas's own
    // design pixels come through unscaled: blur 34, so spread 17.
    check("a stock base-size 12 box keeps the canvas's own design pixels",
          Shadow.growth(17, 3, 0), 17)
    check("one ring is the whole spread and nothing inside it",
          Shadow.growth(20, 1, 0), 20)
    // steps is a divisor, so zero has to answer rather than return Infinity into an anchor margin.
    check("no rings answers zero rather than dividing by zero",
          Shadow.growth(20, 0, 0), 0)

    // The visible band reaches the edge alpha, half the canvas's declared 0.5 peak, because that is
    // where a Gaussian sits on the shape's own edge: 1 - (1 - a)^3 = 0.25.
    check("three rings stack to the edge alpha",
          Math.round((1 - Math.pow(1 - Shadow.stepAlpha(0.25, 3), 3)) * 1000), 250)
    check("a single ring carries the whole edge alpha itself",
          Shadow.stepAlpha(0.25, 1), 0.25)
    check("eight rings still stack to the same darkness, only smoother",
          Math.round((1 - Math.pow(1 - Shadow.stepAlpha(0.25, 8), 8)) * 1000), 250)
    check("each ring is fainter than the total it stacks to",
          Shadow.stepAlpha(0.25, 3) < 0.25, true)
    // The outermost band is a single ring, and on this theme's background it is the step that would
    // show as a hard terminating edge if it were too dark: 9 percent of black, about 2 of 255.
    check("the outermost band is under a tenth of black",
          Shadow.stepAlpha(0.25, 3) < 0.1, true)
    check("no rings answers zero alpha rather than dividing by zero",
          Shadow.stepAlpha(0.5, 0), 0)
    check("an edge alpha of zero draws nothing at all",
          Shadow.stepAlpha(0, 3), 0)

    // This box carries hyprland decoration:rounding 8, so every ring is concentric with the card.
    check("a rounded surface grows its corner with each ring",
          Shadow.ringRadius(8, 20) + "|" + Shadow.ringRadius(8, 13) + "|" + Shadow.ringRadius(8, 7),
          "28|21|15")
    // Stock Omarchy ships decoration:rounding 0, and a rounded ring around a square card would leave
    // the card's own corners poking out of its shadow.
    check("a square surface keeps square rings",
          Shadow.ringRadius(0, 20), 0)
}
