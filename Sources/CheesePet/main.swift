import AppKit

if CommandLine.arguments.contains("--self-test") {
    do {
        let assets = try SpriteAssets(requireBundledAssets: true)
        print("SELF-TEST PASSED: bundled atlas \(assets.manifest.width)x\(assets.manifest.height), \(assets.manifest.animations.count) animations, \(assets.manifest.lookDirections.count) gaze directions")
        exit(EXIT_SUCCESS)
    } catch {
        FileHandle.standardError.write(Data("SELF-TEST FAILED: \(error.localizedDescription)\n".utf8))
        exit(EXIT_FAILURE)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: PetController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Avoid duplicate pets when launched again via Finder or the installer.
        if let identifier = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: identifier).count > 1 {
            NSApp.terminate(nil)
            return
        }
        do {
            controller = PetController(assets: try SpriteAssets())
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "雪糕暂时没能出现"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "退出")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) { controller?.stop() }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
