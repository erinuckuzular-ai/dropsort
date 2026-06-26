import Cocoa

let S: CGFloat = 1024
let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// ---- rounded-square (squircle-ish) background with gradient ----
let inset: CGFloat = 100
let rect = NSRect(x: inset, y: inset, width: S - inset*2, height: S - inset*2)
let radius: CGFloat = 185
let bg = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
bg.addClip()

let top = NSColor(calibratedRed: 0.33, green: 0.80, blue: 0.99, alpha: 1)   // #54CCFC
let bot = NSColor(calibratedRed: 0.16, green: 0.38, blue: 1.00, alpha: 1)   // #2962FF
let grad = NSGradient(starting: top, ending: bot)!
grad.draw(in: rect, angle: -90)

// subtle top sheen
NSColor(white: 1, alpha: 0.10).setFill()
NSBezierPath(roundedRect: NSRect(x: inset, y: S/2, width: S-inset*2, height: S/2-inset), xRadius: radius, yRadius: radius).fill()

// reset clip for the mark
ctx.resetClip()

// ---- water drop (white) ----
let cx: CGFloat = 512
let cyCircle: CGFloat = 555
let r: CGFloat = 168
let pointY = cyCircle + r * 1.62

let drop = NSBezierPath()
drop.move(to: NSPoint(x: cx, y: pointY))
// left side: point -> widest (left of circle), convex
drop.curve(to: NSPoint(x: cx - r, y: cyCircle),
           controlPoint1: NSPoint(x: cx - r*0.62, y: pointY - r*0.46),
           controlPoint2: NSPoint(x: cx - r*1.02, y: cyCircle + r*0.62))
// rounded bottom
drop.appendArc(withCenter: NSPoint(x: cx, y: cyCircle), radius: r, startAngle: 180, endAngle: 360, clockwise: false)
// right side: widest -> point, convex
drop.curve(to: NSPoint(x: cx, y: pointY),
           controlPoint1: NSPoint(x: cx + r*1.02, y: cyCircle + r*0.62),
           controlPoint2: NSPoint(x: cx + r*0.62, y: pointY - r*0.46))
drop.close()
NSColor.white.setFill()
drop.fill()

// water shine: soft highlight upper-left of the drop body
let hi = NSBezierPath(ovalIn: NSRect(x: cx - r*0.62, y: cyCircle + r*0.02, width: r*0.46, height: r*0.66))
NSColor(calibratedRed: 0.40, green: 0.84, blue: 1.0, alpha: 0.22).setFill()
hi.fill()

// ---- sorted bars beneath ----
func bar(_ width: CGFloat, _ y: CGFloat, _ alpha: CGFloat) {
    let x = cx - width/2
    let p = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: width, height: 46), xRadius: 23, yRadius: 23)
    NSColor(white: 1, alpha: alpha).setFill()
    p.fill()
}
bar(360, 330, 1.0)
bar(264, 252, 0.85)
bar(168, 174, 0.7)

img.unlockFocus()

// ---- write PNG ----
let outPath = CommandLine.arguments[1]
if let tiff = img.tiffRepresentation,
   let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    try! png.write(to: URL(fileURLWithPath: outPath))
    print("wrote \(outPath)")
}
