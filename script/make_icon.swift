import AppKit
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = base * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let size = CGFloat(pixels)
        let rect = NSRect(x: size * 0.05, y: size * 0.05, width: size * 0.9, height: size * 0.9)
        NSColor(calibratedRed: 0.025, green: 0.055, blue: 0.085, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: size * 0.21, yRadius: size * 0.21).fill()
        let cyan = NSColor(calibratedRed: 0.5, green: 0.85, blue: 0.96, alpha: 1)
        for index in 1...3 {
            let radius = size * CGFloat(index) * 0.11
            cyan.withAlphaComponent(index == 3 ? 0.8 : 0.25).setStroke()
            let ring = NSBezierPath(ovalIn: NSRect(x: size/2-radius, y: size/2-radius, width: radius*2, height: radius*2))
            ring.lineWidth = max(1, size * 0.008); ring.stroke()
        }
        cyan.setStroke()
        let ray = NSBezierPath(); ray.move(to: NSPoint(x: size * 0.5, y: size * 0.5)); ray.line(to: NSPoint(x: size * 0.73, y: size * 0.73)); ray.lineWidth = size * 0.018; ray.stroke()
        cyan.setFill(); NSBezierPath(ovalIn: NSRect(x: size * 0.47, y: size * 0.47, width: size * 0.06, height: size * 0.06)).fill()
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("icon_\(base)x\(base)\(suffix).png"))
    }
}
