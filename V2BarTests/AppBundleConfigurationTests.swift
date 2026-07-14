import CoreGraphics
import Foundation
import ImageIO
import XCTest

final class AppBundleConfigurationTests: XCTestCase {
    private var repositoryRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testAppIconProvidesBundledAppearanceVariants() throws {
        let appIconURL = repositoryRootURL
            .appendingPathComponent("V2Bar/Resources/AppIcon.icon")
        let configurationURL = appIconURL.appendingPathComponent("icon.json")

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: configurationURL.path),
            "The bundled AppIcon.icon configuration must exist."
        )

        let data = try Data(contentsOf: configurationURL)
        let configuration = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let fillSpecializations = try XCTUnwrap(
            configuration["fill-specializations"] as? [String: Any]
        )
        XCTAssertNotNil(fillSpecializations["dark"])
        XCTAssertNotNil(fillSpecializations["tinted"])

        let groups = try XCTUnwrap(configuration["groups"] as? [[String: Any]])
        let layers = try XCTUnwrap(groups.first?["layers"] as? [[String: Any]])
        let layer = try XCTUnwrap(layers.first)
        let defaultImageName = try XCTUnwrap(layer["image-name"] as? String)
        let imageSpecializations = try XCTUnwrap(
            layer["image-name-specializations"] as? [String: String]
        )
        let darkImageName = try XCTUnwrap(imageSpecializations["dark"])
        let tintedImageName = try XCTUnwrap(imageSpecializations["tinted"])

        for imageName in [defaultImageName, darkImageName, tintedImageName] {
            let imageURL = appIconURL.appendingPathComponent("Assets/\(imageName)")
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: imageURL.path),
                "The AppIcon.icon image \(imageName) must exist."
            )

            let source = try XCTUnwrap(CGImageSourceCreateWithURL(imageURL as CFURL, nil))
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            XCTAssertEqual(image.width, 1_024)
            XCTAssertEqual(image.height, 1_024)
            XCTAssertTrue(
                [.premultipliedLast, .premultipliedFirst, .last, .first]
                    .contains(image.alphaInfo),
                "The AppIcon.icon image \(imageName) must contain an alpha channel."
            )
        }

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: repositoryRootURL
                    .appendingPathComponent("V2Bar/Resources/Assets.xcassets/AppIcon.appiconset")
                    .path
            ),
            "The legacy AppIcon.appiconset must not conflict with AppIcon.icon."
        )
    }

    func testReadmeUsesGeneratedAdaptiveAppIconPreviews() throws {
        let previewDirectoryURL = repositoryRootURL
            .appendingPathComponent("Design/AppIcon/Previews")
        let previewNames = [
            "v2bar-icon-default.png",
            "v2bar-icon-dark.png",
        ]

        for previewName in previewNames {
            XCTAssertTrue(
                FileManager.default.fileExists(
                    atPath: previewDirectoryURL.appendingPathComponent(previewName).path
                ),
                "The generated README preview \(previewName) must exist."
            )
        }

        let readmeURL = repositoryRootURL.appendingPathComponent("README.md")
        let contents = try String(contentsOf: readmeURL, encoding: .utf8)

        for previewName in previewNames {
            XCTAssertTrue(contents.contains("Design/AppIcon/Previews/\(previewName)"))
        }
        XCTAssertFalse(contents.contains("Screenshots/icon.png"))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: repositoryRootURL.appendingPathComponent("Screenshots/icon.png").path
            ),
            "The obsolete static README icon must be removed."
        )
    }

    func testAppIconMarkKeepsVAndTwoSeparated() throws {
        let imageURL = repositoryRootURL
            .appendingPathComponent(
                "V2Bar/Resources/AppIcon.icon/Assets/v2bar-mark-default.png"
            )
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(imageURL as CFURL, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let bytesPerPixel = 4
        let bytesPerRow = image.width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * image.height)

        try pixels.withUnsafeMutableBytes { buffer in
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
            let context = try XCTUnwrap(
                CGContext(
                    data: buffer.baseAddress,
                    width: image.width,
                    height: image.height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: bitmapInfo
                )
            )
            context.draw(
                image,
                in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
            )
        }

        func containsOpaquePixel(in xRange: Range<Int>) -> Bool {
            for y in 0 ..< image.height {
                for x in xRange where pixels[y * bytesPerRow + x * bytesPerPixel + 3] > 0 {
                    return true
                }
            }
            return false
        }

        XCTAssertTrue(containsOpaquePixel(in: 0 ..< 560), "The V mark must exist.")
        XCTAssertTrue(
            containsOpaquePixel(in: 596 ..< image.width),
            "The numeral 2 must exist."
        )

        var opaqueGapPixel: CGPoint?
        gapSearch: for y in 0 ..< image.height {
            for x in 560 ..< 596 where pixels[y * bytesPerRow + x * bytesPerPixel + 3] > 0 {
                opaqueGapPixel = CGPoint(x: x, y: y)
                break gapSearch
            }
        }
        XCTAssertNil(
            opaqueGapPixel,
            "V and 2 must be separated by a fully transparent vertical gutter."
        )
    }
}
