.pragma library

// WCAG 2.1 relative luminance, so a test can assert a ratio rather than an eye judging a screenshot.
function channel(c) {
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
}

function luminance(r, g, b) {
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
}

// Sample input: "#c8ccd0"
function parse(hex) {
    var s = String(hex).replace("#", "")
    return [parseInt(s.substr(0, 2), 16) / 255,
            parseInt(s.substr(2, 2), 16) / 255,
            parseInt(s.substr(4, 2), 16) / 255]
}

function over(fg, alpha, bg) {
    var f = parse(fg)
    var b = parse(bg)
    return [f[0] * alpha + b[0] * (1 - alpha),
            f[1] * alpha + b[1] * (1 - alpha),
            f[2] * alpha + b[2] * (1 - alpha)]
}

function ratioOf(a, b) {
    var la = luminance(a[0], a[1], a[2])
    var lb = luminance(b[0], b[1], b[2])
    var hi = Math.max(la, lb)
    var lo = Math.min(la, lb)
    return (hi + 0.05) / (lo + 0.05)
}

function ratio(fgHex, bgHex) {
    return ratioOf(parse(fgHex), parse(bgHex))
}
