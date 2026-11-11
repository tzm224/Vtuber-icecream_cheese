import Foundation

public struct SpriteManifest: Decodable {
    public let image: String
    public let width: Int
    public let height: Int
    public let columns: Int
    public let rows: Int
    public let cellWidth: Int
    public let cellHeight: Int
    public let pixelRatio: Double?
    public let animations: [String: SpriteAnimation]
    public let lookDirections: [LookDirection]

    public var logicalCellWidth: Double { Double(cellWidth) / (pixelRatio ?? 1) }
    public var logicalCellHeight: Double { Double(cellHeight) / (pixelRatio ?? 1) }

    public func validate() throws {
        guard columns > 0, rows > 0, cellWidth > 0, cellHeight > 0,
              (pixelRatio ?? 1).isFinite, (pixelRatio ?? 1) >= 1, (pixelRatio ?? 1) <= 4,
              width == columns * cellWidth, height == rows * cellHeight,
              image == URL(fileURLWithPath: image).lastPathComponent,
              !image.isEmpty else { throw AssetError.invalidManifest }
        for name in ["idle", "running-left", "running-right", "waving", "jumping", "failed", "waiting", "running", "review"] {
            guard let animation = animations[name], animation.row >= 0, animation.row < rows,
                  animation.frames > 0, animation.frames <= columns,
                  animation.durationsMs.count == animation.frames,
                  animation.durationsMs.allSatisfy({ $0 > 0 }) else { throw AssetError.invalidManifest }
        }
        guard lookDirections.count == 16,
              lookDirections.map(\.angle) == (0..<16).map({ Double($0) * 22.5 }),
              lookDirections.allSatisfy({ $0.row >= 0 && $0.row < rows && $0.column >= 0 && $0.column < columns && $0.angle.isFinite })
        else { throw AssetError.invalidManifest }
    }
}

public struct LookDirection: Decodable {
    public let angle: Double
    public let row: Int
    public let column: Int
}

public struct SpriteAnimation: Decodable {
    public let row: Int
    public let frames: Int
    public let durationsMs: [Int]
    public let loop: Bool

    public init(row: Int, frames: Int, durationsMs: [Int], loop: Bool) {
        self.row = row
        self.frames = frames
        self.durationsMs = durationsMs
        self.loop = loop
    }

    public var duration: TimeInterval { Double(durationsMs.reduce(0, +)) / 1_000 }

    public func frame(at elapsed: TimeInterval) -> Int {
        guard duration > 0, frames > 0, elapsed.isFinite else { return 0 }
        if !loop && elapsed >= duration { return frames - 1 }
        var remaining = max(0, elapsed)
        if loop { remaining = remaining.truncatingRemainder(dividingBy: duration) }
        for (index, milliseconds) in durationsMs.enumerated() {
            let seconds = Double(milliseconds) / 1_000
            if remaining < seconds { return min(index, frames - 1) }
            remaining -= seconds
        }
        return frames - 1
    }
}

public enum AssetError: Error, LocalizedError {
    case invalidManifest
    case missingAssets
    case invalidImage

    public var errorDescription: String? {
        switch self {
        case .invalidManifest: return "动画清单不完整或格式不正确。"
        case .missingAssets: return "找不到桌宠素材。请重新安装完整的 CheesePet.app。"
        case .invalidImage: return "桌宠图像损坏，或尺寸与动画清单不一致。"
        }
    }
}
