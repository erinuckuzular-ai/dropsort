import Cocoa

let W: CGFloat = 660, H: CGFloat = 420
let img = NSImage(size: NSSize(width: W, height: H))
img.lockFocus()

// soft gradient background
let g = NSGradient(starting: NSColor(calibratedRed: 0.97, green: 0.98, blue: 1.0, alpha: 1),
                   ending:   NSColor(calibratedRed: 0.90, green: 0.94, blue: 1.0, alpha: 1))!
g.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

// title
let titleAttr: [NSAttributedString.Key: Any] = [
    .font: NSFont.boldSystemFont(ofSize: 30),
    .foregroundColor: NSColor(calibratedRed: 0.12, green: 0.20, blue: 0.40, alpha: 1)
]
let title = NSAttributedString(string: "Install Dropsort", attributes: titleAttr)
title.draw(at: NSPoint(x: (W - title.size().width)/2, y: H - 78))

let subAttr: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 15),
    .foregroundColor: NSColor(calibratedRed: 0.30, green: 0.38, blue: 0.55, alpha: 1)
]
let sub = NSAttributedString(string: "Drag the Dropsort icon onto the Applications folder", attributes: subAttr)
sub.draw(at: NSPoint(x: (W - sub.size().width)/2, y: H - 110))

// arrow between the two icon positions (icons sit at x≈165 and x≈495, y from top ≈ 230 → y_img ≈ 190)
let yMid: CGFloat = H - 232
let arrowColor = NSColor(calibratedRed: 0.16, green: 0.38, blue: 1.0, alpha: 0.85)
arrowColor.setStroke(); arrowColor.setFill()
let shaft = NSBezierPath()
shaft.lineWidth = 9
shaft.lineCapStyle = .round
shaft.move(to: NSPoint(x: 268, y: yMid))
shaft.line(to: NSPoint(x: 372, y: yMid))
shaft.stroke()
let head = NSBezierPath()
head.move(to: NSPoint(x: 404, y: yMid))
head.line(to: NSPoint(x: 366, y: yMid + 22))
head.line(to: NSPoint(x: 366, y: yMid - 22))
head.close()
head.fill()

// faint footer
let footAttr: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11),
    .foregroundColor: NSColor(calibratedRed: 0.45, green: 0.52, blue: 0.66, alpha: 1)
]
let foot = NSAttributedString(string: "First launch: right-click Dropsort → Open", attributes: footAttr)
foot.draw(at: NSPoint(x: (W - foot.size().width)/2, y: 26))

img.unlockFocus()
if let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    print("wrote bg")
}
