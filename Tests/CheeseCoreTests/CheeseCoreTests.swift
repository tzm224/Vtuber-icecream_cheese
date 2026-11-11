import XCTest
import CoreGraphics
@testable import CheeseCore

final class CheeseCoreTests: XCTestCase {
    func testAnimationTimingAndLooping() {
        let animation = SpriteAnimation(row: 0, frames: 3, durationsMs: [100, 200, 300], loop: true)
        XCTAssertEqual(animation.frame(at: 0), 0)
        XCTAssertEqual(animation.frame(at: 0.11), 1)
        XCTAssertEqual(animation.frame(at: 0.31), 2)
        XCTAssertEqual(animation.frame(at: 0.61), 0)
        XCTAssertEqual(animation.duration, 0.6, accuracy: 0.00001)
    }

    func testNonLoopingAnimationHoldsLastFrame() {
        let animation = SpriteAnimation(row: 0, frames: 2, durationsMs: [100, 100], loop: false)
        XCTAssertEqual(animation.frame(at: -4), 0)
        XCTAssertEqual(animation.frame(at: 100), 1)
        XCTAssertEqual(animation.frame(at: .infinity), 0)
    }

    func testLookCardinalsAndDiagonals() {
        XCTAssertEqual(PetGeometry.lookIndex(dx: 0, dy: 1), 0)
        XCTAssertEqual(PetGeometry.lookIndex(dx: 1, dy: 1), 2)
        XCTAssertEqual(PetGeometry.lookIndex(dx: 1, dy: 0), 4)
        XCTAssertEqual(PetGeometry.lookIndex(dx: 0, dy: -1), 8)
        XCTAssertEqual(PetGeometry.lookIndex(dx: -1, dy: 0), 12)
        XCTAssertEqual(PetGeometry.lookIndex(dx: -0.001, dy: 1), 0)
    }

    func testAllSixteenDirections() {
        for index in 0..<16 {
            let radians = Double(index) * 22.5 * .pi / 180
            XCTAssertEqual(PetGeometry.lookIndex(dx: sin(radians), dy: cos(radians)), index)
        }
    }

    func testScreenClampingWithNegativeCoordinates() {
        let bounds = CGRect(x: -1_920, y: -300, width: 1_920, height: 1_080)
        let size = CGSize(width: 192, height: 274)
        XCTAssertEqual(PetGeometry.clampedOrigin(CGPoint(x: -3_000, y: -600), size: size, inside: bounds), CGPoint(x: -1_920, y: -300))
        XCTAssertEqual(PetGeometry.clampedOrigin(CGPoint(x: 100, y: 900), size: size, inside: bounds), CGPoint(x: -192, y: 506))
    }

    func testWindowLargerThanScreenDoesNotInvertRange() {
        XCTAssertEqual(PetGeometry.clampedOrigin(CGPoint(x: 500, y: 500), size: CGSize(width: 200, height: 200),
            inside: CGRect(x: 0, y: 0, width: 100, height: 100)), .zero)
    }

    func testWalkingCannotOvershootOrJumpAfterWake() {
        XCTAssertEqual(PetGeometry.walkingStep(x: 1, target: 2, speed: 34, dt: 0.1), 2)
        XCTAssertEqual(PetGeometry.walkingStep(x: 2, target: 1, speed: 34, dt: 0.1), 1)
        XCTAssertEqual(PetGeometry.walkingStep(x: 0, target: 500, speed: 34, dt: 3_600), 3.4, accuracy: 0.00001)
        XCTAssertEqual(PetGeometry.walkingStep(x: 10, target: 50, speed: 34, dt: -1), 10)
    }

    func testActualManifestIsValidAndReferencesExpectedAtlas() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let manifest = try JSONDecoder().decode(SpriteManifest.self, from: Data(contentsOf: root.appendingPathComponent("Assets/animation-manifest.json")))
        try manifest.validate()
        XCTAssertEqual(manifest.logicalCellWidth, 192)
        XCTAssertEqual(manifest.logicalCellHeight, 208)
        XCTAssertEqual(manifest.animations.count, 9)
        XCTAssertEqual(manifest.animations.values.reduce(0) { $0 + $1.frames }, 57)
        XCTAssertEqual(manifest.lookDirections.map(\.angle), (0..<16).map { Double($0) * 22.5 })
    }

    func testInvalidManifestIsRejected() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Assets/animation-manifest.json"))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["image"] = "../unexpected.png"
        let invalid = try JSONDecoder().decode(SpriteManifest.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertThrowsError(try invalid.validate())
    }

    func testRetinaAssetsKeepLogicalSize() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Assets/animation-manifest.json"))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["pixelRatio"] = 2.0
        object["cellWidth"] = 384
        object["cellHeight"] = 416
        object["width"] = 3_072
        object["height"] = 4_576
        let retina = try JSONDecoder().decode(SpriteManifest.self, from: JSONSerialization.data(withJSONObject: object))
        try retina.validate()
        XCTAssertEqual(retina.logicalCellWidth, 192)
        XCTAssertEqual(retina.logicalCellHeight, 208)
    }
}
