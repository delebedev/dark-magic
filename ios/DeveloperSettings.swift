import Foundation

enum LaunchMode: String, CaseIterable {
    case normal, gameWorld = "game_world", spellLab = "spell_lab", warpLab = "warp_lab", uiLab = "ui_lab"

    var title: String {
        switch self {
        case .normal: return "Normal game"
        case .gameWorld: return "Game World · Amazon"
        case .spellLab: return "Spell Lab"
        case .warpLab: return "Warp Lab"
        case .uiLab: return "UI Lab"
        }
    }

    var scene: String { self == .normal ? "" : rawValue }
}

// Owns mobile launch preferences; engine preferences and campaign saves remain in their existing owners.
final class DeveloperSettings {
    private let defaults: UserDefaults
    private static let modeKey = "developer.launchMode"
    private static let diagnosticsKey = "developer.inputDiagnostics"
    private static let performanceKey = "developer.performanceOverlay"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var launchMode: LaunchMode {
        get { LaunchMode(rawValue: defaults.string(forKey: Self.modeKey) ?? "normal") ?? .normal }
        set { defaults.set(newValue.rawValue, forKey: Self.modeKey) }
    }

    var inputDiagnostics: Bool {
        get { defaults.bool(forKey: Self.diagnosticsKey) }
        set { defaults.set(newValue, forKey: Self.diagnosticsKey) }
    }

    var haptics: Bool {
        get { defaults.object(forKey: "feedback.haptics") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feedback.haptics") }
    }

    var performanceOverlay: Bool {
        get { defaults.bool(forKey: Self.performanceKey) }
        set { defaults.set(newValue, forKey: Self.performanceKey) }
    }

    func resolvedScene(environment: [String: String]) -> String {
        if let scene = environment["DARK_MAGIC_START_SCENE"], !scene.isEmpty { return scene }
        return launchMode.scene
    }

    func resolvedDiagnostics(environment: [String: String]) -> Bool {
        if let value = environment["DARK_MAGIC_INPUT_DIAGNOSTICS"] { return value == "1" }
        return inputDiagnostics
    }
}
