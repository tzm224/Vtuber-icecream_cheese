import AppKit
import CoreGraphics
import CheeseCore

final class SpriteAssets {
    let manifest: SpriteManifest
    private var frames: [Int: NSImage] = [:]
    private var bitmapFrames: [Int: NSBitmapImageRep] = [:]

    init(requireBundledAssets: Bool = false) throws {
        let developmentRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let developmentCandidates = [
            Bundle.main.resourceURL?.appendingPathComponent("Assets"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Assets"),
            developmentRoot.appendingPathComponent("Assets")
        ].compactMap { $0 }
        let isAppBundle = Bundle.main.bundleURL.pathExtension.lowercased() == "app"
        let candidates = requireBundledAssets || isAppBundle
            ? [Bundle.main.resourceURL?.appendingPathComponent("Assets")].compactMap { $0 }
            : developmentCandidates
        guard let directory = candidates.first(where: {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("animation-manifest.json").path)
        }) else { throw AssetError.missingAssets }
        manifest = try JSONDecoder().decode(SpriteManifest.self, from: Data(contentsOf: directory.appendingPathComponent("animation-manifest.json")))
        try manifest.validate()
        guard let source = NSImage(contentsOf: directory.appendingPathComponent(manifest.image)),
              let cgImage = source.cgImage(forProposedRect: nil, context: nil, hints: nil),
              cgImage.width == manifest.width, cgImage.height == manifest.height
        else { throw AssetError.invalidImage }

        for row in 0..<manifest.rows {
            for column in 0..<manifest.columns {
                let crop = CGRect(x: CGFloat(column * manifest.cellWidth), y: CGFloat(row * manifest.cellHeight),
                                  width: CGFloat(manifest.cellWidth), height: CGFloat(manifest.cellHeight))
                guard let cgFrame = cgImage.cropping(to: crop) else { throw AssetError.invalidImage }
                let key = row * manifest.columns + column
                frames[key] = NSImage(cgImage: cgFrame, size: NSSize(width: manifest.logicalCellWidth, height: manifest.logicalCellHeight))
                bitmapFrames[key] = NSBitmapImageRep(cgImage: cgFrame)
            }
        }
    }

    func image(row: Int, column: Int) -> NSImage? { frames[row * manifest.columns + column] }

    func isOpaque(row: Int, column: Int, x: Double, y: Double) -> Bool {
        guard x >= 0, y >= 0, x < Double(manifest.cellWidth), y < Double(manifest.cellHeight),
              let bitmap = bitmapFrames[row * manifest.columns + column] else { return false }
        return (bitmap.colorAt(x: Int(x), y: Int(y))?.alphaComponent ?? 0) > 0.12
    }
}
