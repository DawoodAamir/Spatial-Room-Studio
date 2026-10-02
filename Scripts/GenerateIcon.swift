import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(
  "Resources/Assets.xcassets/AppIcon.solidimagestack")
let info: [String: Any] = ["author": "xcode", "version": 1]
func json(_ value: [String: Any], _ url: URL) throws {
  try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(
    to: url)
}
let names = ["Front", "Back"]
try json(
  ["info": info, "layers": names.map { ["filename": "\($0).solidimagestacklayer"] }],
  output.appendingPathComponent("Contents.json"))
for name in names {
  let layer = output.appendingPathComponent("\(name).solidimagestacklayer")
  let images = layer.appendingPathComponent("Content.imageset")
  try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
  try json(["info": info], layer.appendingPathComponent("Contents.json"))
  try json(
    ["info": info, "images": [["idiom": "universal", "filename": "Layer.png", "scale": "1x"]]],
    images.appendingPathComponent("Contents.json"))
  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: 512, pixelsHigh: 512, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  let scale = NSAffineTransform()
  scale.scale(by: 0.5)
  scale.concat()
  if name == "Back" {
    NSColor(calibratedRed: 0.16, green: 0.25, blue: 0.24, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
  } else {
    NSColor(calibratedRed: 0.90, green: 0.80, blue: 0.61, alpha: 1).setStroke()
    let room = NSBezierPath()
    room.move(to: NSPoint(x: 240, y: 300))
    room.line(to: NSPoint(x: 240, y: 740))
    room.line(to: NSPoint(x: 784, y: 740))
    room.line(to: NSPoint(x: 784, y: 300))
    room.lineWidth = 42
    room.lineJoinStyle = .round
    room.stroke()
    NSColor(calibratedWhite: 0.94, alpha: 1).setFill()
    NSBezierPath(
      roundedRect: NSRect(x: 340, y: 470, width: 344, height: 170), xRadius: 28, yRadius: 28
    ).fill()
    NSColor(calibratedRed: 0.65, green: 0.76, blue: 0.67, alpha: 1).setFill()
    NSBezierPath(
      roundedRect: NSRect(x: 420, y: 290, width: 184, height: 95), xRadius: 18, yRadius: 18
    ).fill()
  }
  NSGraphicsContext.restoreGraphicsState()
  try bitmap.representation(using: .png, properties: [:])!.write(
    to: images.appendingPathComponent("Layer.png"))
}
