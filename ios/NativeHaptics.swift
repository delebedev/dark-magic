import UIKit
import Darkmagicmobile

final class NativeHaptics: NSObject, DarkmagicmobileFeedbackHandlerProtocol {
    private let press = UIImpactFeedbackGenerator(style: .soft)
    private let activate = UIImpactFeedbackGenerator(style: .light)
    private let release = UIImpactFeedbackGenerator(style: .medium)
    private var enabled = false
    private var enabledSince: TimeInterval = 0

    func setEnabled(_ enabled: Bool) {
        guard self.enabled != enabled else { return }
        self.enabled = enabled
        enabledSince = ProcessInfo.processInfo.systemUptime
        DarkmagicmobileSetFeedbackEnabled(enabled)
    }

    func pulse(_ kind: String?) {
        let requested = ProcessInfo.processInfo.systemUptime
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.enabled, requested >= self.enabledSince,
                  ProcessInfo.processInfo.systemUptime - requested < 0.1,
                  UIApplication.shared.applicationState == .active else { return }
            if ProcessInfo.processInfo.environment["DARK_MAGIC_INPUT_DIAGNOSTICS"] == "1" {
                NSLog("Dark Magic feedback: %@", kind ?? "unknown")
            }
            #if !targetEnvironment(simulator)
            switch kind {
            case "press": self.press.impactOccurred(intensity: 0.35)
            case "activate": self.activate.impactOccurred(intensity: 0.4)
            case "release": self.release.impactOccurred(intensity: 0.65)
            default: return
            }
            #endif
        }
    }
}
