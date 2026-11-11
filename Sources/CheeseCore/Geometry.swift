import Foundation
import CoreGraphics

public enum PetGeometry {
    /// AppKit coordinates: positive y points up. Angle zero points up, clockwise.
    public static func lookIndex(dx: Double, dy: Double) -> Int {
        guard dx.isFinite, dy.isFinite else { return 0 }
        let angle = atan2(dx, dy) * 180 / .pi
        return Int(((angle + 360).truncatingRemainder(dividingBy: 360) / 22.5).rounded()) % 16
    }

    public static func clampedOrigin(_ origin: CGPoint, size: CGSize, inside bounds: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(origin.x, bounds.minX), max(bounds.minX, bounds.maxX - size.width)),
            y: min(max(origin.y, bounds.minY), max(bounds.minY, bounds.maxY - size.height))
        )
    }

    public static func walkingStep(x: Double, target: Double, speed: Double, dt: Double) -> Double {
        guard x.isFinite, target.isFinite, speed.isFinite, dt.isFinite else { return x }
        let distance = max(0, speed) * min(max(0, dt), 0.1)
        if target > x { return min(target, x + distance) }
        return max(target, x - distance)
    }
}
