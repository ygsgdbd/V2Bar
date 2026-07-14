import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private struct Palette {
    let mark: NSColor
    let backgroundTop: NSColor
    let backgroundBottom: NSColor
}

private let defaultPalette = Palette(
    mark: NSColor(calibratedRed: 0.137, green: 0.165, blue: 0.196, alpha: 1.0),
    backgroundTop: NSColor(calibratedRed: 0.965, green: 0.970, blue: 0.980, alpha: 1.0),
    backgroundBottom: NSColor(calibratedRed: 0.885, green: 0.895, blue: 0.910, alpha: 1.0)
)

private let darkPalette = Palette(
    mark: NSColor(calibratedRed: 0.933, green: 0.953, blue: 0.973, alpha: 1.0),
    backgroundTop: NSColor(calibratedRed: 0.185, green: 0.185, blue: 0.185, alpha: 1.0),
    backgroundBottom: NSColor(calibratedRed: 0.050, green: 0.054, blue: 0.060, alpha: 1.0)
)

private let monoPalette = Palette(
    mark: NSColor(calibratedWhite: 0.96, alpha: 1.0),
    backgroundTop: NSColor(calibratedWhite: 0.92, alpha: 1.0),
    backgroundBottom: NSColor(calibratedWhite: 0.72, alpha: 1.0)
)

private let size = 1_024

private func context() -> CGContext {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        | CGBitmapInfo.byteOrder32Big.rawValue
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        fatalError("Unable to create bitmap context.")
    }
    context.interpolationQuality = .high
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    return context
}

private func flip(_ context: CGContext) {
    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: 1, y: -1)
}

private func drawMark(color: NSColor, in context: CGContext) {
    context.setFillColor(color.cgColor)

    let vPath = CGMutablePath()
    vPath.move(to: CGPoint(x: 232, y: 360))
    vPath.addLine(to: CGPoint(x: 316, y: 360))
    vPath.addLine(to: CGPoint(x: 392, y: 560))
    vPath.addLine(to: CGPoint(x: 468, y: 360))
    vPath.addLine(to: CGPoint(x: 552, y: 360))
    vPath.addLine(to: CGPoint(x: 430, y: 656))
    vPath.addQuadCurve(
        to: CGPoint(x: 420, y: 664),
        control: CGPoint(x: 427, y: 664)
    )
    vPath.addLine(to: CGPoint(x: 364, y: 664))
    vPath.addQuadCurve(
        to: CGPoint(x: 354, y: 656),
        control: CGPoint(x: 357, y: 664)
    )
    vPath.closeSubpath()
    context.addPath(vPath)
    context.fillPath()

    let twoPath = CGMutablePath()
    twoPath.move(to: CGPoint(x: 620, y: 360))
    twoPath.addLine(to: CGPoint(x: 772, y: 360))
    twoPath.addQuadCurve(
        to: CGPoint(x: 838, y: 426),
        control: CGPoint(x: 838, y: 360)
    )
    twoPath.addLine(to: CGPoint(x: 838, y: 454))
    twoPath.addQuadCurve(
        to: CGPoint(x: 814, y: 496),
        control: CGPoint(x: 838, y: 480)
    )
    twoPath.addLine(to: CGPoint(x: 686, y: 582))
    twoPath.addLine(to: CGPoint(x: 830, y: 582))
    twoPath.addLine(to: CGPoint(x: 830, y: 664))
    twoPath.addLine(to: CGPoint(x: 640, y: 664))
    twoPath.addLine(to: CGPoint(x: 640, y: 582))
    twoPath.addLine(to: CGPoint(x: 770, y: 474))
    twoPath.addLine(to: CGPoint(x: 770, y: 442))
    twoPath.addLine(to: CGPoint(x: 620, y: 442))
    twoPath.closeSubpath()
    context.addPath(twoPath)
    context.fillPath()
}

private func drawLayer(palette: Palette, output: URL) throws {
    let context = context()
    flip(context)
    drawMark(color: palette.mark, in: context)
    try writePNG(context: context, output: output)
}

private func drawPreview(palette: Palette, output: URL) throws {
    let context = context()
    flip(context)

    let iconRect = CGRect(x: 0, y: 0, width: size, height: size)
    context.saveGState()
    context.addPath(
        CGPath(
            roundedRect: iconRect,
            cornerWidth: 220,
            cornerHeight: 220,
            transform: nil
        )
    )
    context.clip()

    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [palette.backgroundTop.cgColor, palette.backgroundBottom.cgColor] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: 0),
        end: CGPoint(x: 0, y: CGFloat(size)),
        options: []
    )

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: 18),
        blur: 24,
        color: NSColor(calibratedWhite: 0.0, alpha: 0.24).cgColor
    )
    drawMark(color: palette.mark, in: context)
    context.restoreGState()

    drawMark(color: palette.mark, in: context)

    context.setStrokeColor(NSColor(calibratedWhite: 1.0, alpha: 0.28).cgColor)
    context.setLineWidth(3)
    context.addPath(
        CGPath(
            roundedRect: iconRect.insetBy(dx: 6, dy: 6),
            cornerWidth: 214,
            cornerHeight: 214,
            transform: nil
        )
    )
    context.strokePath()
    context.restoreGState()

    try writePNG(context: context, output: output)
}

private func writePNG(context: CGContext, output: URL) throws {
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(
              output as CFURL,
              UTType.png.identifier as CFString,
              1,
              nil
          )
    else {
        fatalError("Unable to create PNG destination.")
    }
    CGImageDestinationAddImage(destination, image, [
        kCGImagePropertyPNGDictionary: [
            kCGImagePropertyPNGInterlaceType: 0,
        ],
    ] as CFDictionary)
    if !CGImageDestinationFinalize(destination) {
        fatalError("Unable to write \(output.path).")
    }
}

private func ensureDirectory(_ path: String) throws -> URL {
    let url = URL(fileURLWithPath: path, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let iconAssets = try ensureDirectory(
    root.appendingPathComponent("V2Bar/Resources/AppIcon.icon/Assets").path
)
let previews = try ensureDirectory(
    root.appendingPathComponent("Design/AppIcon/Previews").path
)

try drawLayer(
    palette: defaultPalette,
    output: iconAssets.appendingPathComponent("v2bar-mark-default.png")
)
try drawLayer(
    palette: darkPalette,
    output: iconAssets.appendingPathComponent("v2bar-mark-dark.png")
)
try drawLayer(
    palette: monoPalette,
    output: iconAssets.appendingPathComponent("v2bar-mark-mono.png")
)

try drawPreview(
    palette: defaultPalette,
    output: previews.appendingPathComponent("v2bar-icon-default.png")
)
try drawPreview(
    palette: darkPalette,
    output: previews.appendingPathComponent("v2bar-icon-dark.png")
)
try drawPreview(
    palette: monoPalette,
    output: previews.appendingPathComponent("v2bar-icon-mono.png")
)
