// Draws the Hangtag app icon: a white tag holding a picture, hanging by a
// string over a teal gradient.
// Usage: swift scripts/make-icon.swift out.png
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.dropFirst().first ?? "icon.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

func shadow(_ alpha: CGFloat, blur: CGFloat, y: CGFloat) {
    let s = NSShadow()
    s.shadowColor = color(4, 40, 38, alpha)
    s.shadowBlurRadius = blur
    s.shadowOffset = NSSize(width: 0, height: y)
    s.set()
}

// Body, following the macOS icon grid: 824pt square, 100pt margin.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

ctx.saveGState()
shadow(0.30, blur: 26, y: -12)
color(20, 120, 110).setFill()
shape.fill()
ctx.restoreGState()

ctx.saveGState()
shape.addClip()
NSGradient(colors: [color(13, 92, 99), color(20, 150, 130), color(110, 222, 170)],
           atLocations: [0, 0.55, 1], colorSpace: .sRGB)!
    .draw(in: body, angle: 60)
// Soft light from the top.
NSGradient(colors: [color(255, 255, 255, 0.22), color(255, 255, 255, 0)])!
    .draw(in: NSRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)

// The tag, tilted a little, its hole at the top.
let tagWidth: CGFloat = 420, tagHeight: CGFloat = 520, cut: CGFloat = 120
let hole = NSPoint(x: 0, y: tagHeight / 2 - 70)
let transform = NSAffineTransform()
transform.translateX(by: 540, yBy: 440)
transform.rotate(byDegrees: -10)

func tagPath() -> NSBezierPath {
    let w = tagWidth / 2, h = tagHeight / 2
    let p = NSBezierPath()
    p.move(to: NSPoint(x: -w, y: -h + 36))
    p.appendArc(from: NSPoint(x: -w, y: -h), to: NSPoint(x: w, y: -h), radius: 36)
    p.appendArc(from: NSPoint(x: w, y: -h), to: NSPoint(x: w, y: h - cut), radius: 36)
    p.appendArc(from: NSPoint(x: w, y: h - cut), to: NSPoint(x: w - cut, y: h), radius: 28)
    p.appendArc(from: NSPoint(x: w - cut, y: h), to: NSPoint(x: -w + cut, y: h), radius: 28)
    p.appendArc(from: NSPoint(x: -w + cut, y: h), to: NSPoint(x: -w, y: h - cut), radius: 28)
    p.appendArc(from: NSPoint(x: -w, y: h - cut), to: NSPoint(x: -w, y: -h), radius: 28)
    p.close()
    return p
}

// The string, from beyond the top left corner down to the hole.
let holeOnCanvas = transform.transform(hole)
let string = NSBezierPath()
string.move(to: NSPoint(x: 180, y: 980))
string.curve(to: holeOnCanvas,
             controlPoint1: NSPoint(x: 300, y: 860),
             controlPoint2: NSPoint(x: holeOnCanvas.x - 120, y: holeOnCanvas.y + 150))
string.lineWidth = 14
string.lineCapStyle = .round
ctx.saveGState()
shadow(0.25, blur: 10, y: -4)
color(250, 236, 200).setStroke()
string.stroke()
ctx.restoreGState()

ctx.saveGState()
let tag = tagPath()
tag.transform(using: transform as AffineTransform)
shadow(0.35, blur: 40, y: -20)
color(255, 255, 255).setFill()
tag.fill()
ctx.restoreGState()

// The hole, with the string passing through it.
let holeRing = NSBezierPath(ovalIn: NSRect(x: holeOnCanvas.x - 34, y: holeOnCanvas.y - 34, width: 68, height: 68))
color(222, 236, 232).setFill()
holeRing.fill()
let holeInside = NSBezierPath(ovalIn: NSRect(x: holeOnCanvas.x - 20, y: holeOnCanvas.y - 20, width: 40, height: 40))
color(16, 110, 104).setFill()
holeInside.fill()

// A picture on the tag: sky, sun and two hills.
ctx.saveGState()
let picture = NSBezierPath(roundedRect: NSRect(x: -150, y: -200, width: 300, height: 250), xRadius: 26, yRadius: 26)
picture.transform(using: transform as AffineTransform)
picture.addClip()
NSGradient(colors: [color(150, 210, 245), color(205, 236, 250)])!
    .draw(in: picture.bounds, angle: 90)
func placed(_ p: NSBezierPath) -> NSBezierPath { p.transform(using: transform as AffineTransform); return p }
color(255, 196, 70).setFill()
placed(NSBezierPath(ovalIn: NSRect(x: 40, y: -40, width: 70, height: 70))).fill()
let farHill = NSBezierPath()
farHill.move(to: NSPoint(x: -170, y: -210))
farHill.line(to: NSPoint(x: -60, y: -60))
farHill.line(to: NSPoint(x: 60, y: -210))
farHill.close()
color(60, 170, 140).setFill()
placed(farHill).fill()
let nearHill = NSBezierPath()
nearHill.move(to: NSPoint(x: -60, y: -210))
nearHill.line(to: NSPoint(x: 70, y: -100))
nearHill.line(to: NSPoint(x: 180, y: -210))
nearHill.close()
color(24, 128, 112).setFill()
placed(nearHill).fill()
ctx.restoreGState()

ctx.restoreGState()
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
