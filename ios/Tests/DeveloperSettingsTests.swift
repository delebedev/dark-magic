import Foundation

@main
struct DeveloperSettingsTests {
    static func main() {
        let suite = "dark-magic-developer-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = DeveloperSettings(defaults: defaults)
        assert(settings.launchMode == .normal && !settings.inputDiagnostics && !settings.performanceOverlay)
        assert(settings.haptics)
        settings.haptics = false
        assert(!DeveloperSettings(defaults: defaults).haptics)
        settings.haptics = true
        assert(DeveloperSettings(defaults: defaults).haptics)
        assert(settings.resolvedScene(environment: [:]) == "")
        settings.launchMode = .warpLab
        settings.inputDiagnostics = true
        settings.performanceOverlay = true
        let reloaded = DeveloperSettings(defaults: defaults)
        assert(reloaded.launchMode == .warpLab && reloaded.inputDiagnostics && reloaded.performanceOverlay)
        assert(reloaded.resolvedScene(environment: [:]) == "warp_lab")
        assert(reloaded.resolvedScene(environment: ["DARK_MAGIC_START_SCENE": "spell_lab"]) == "spell_lab")
        assert(!reloaded.resolvedDiagnostics(environment: ["DARK_MAGIC_INPUT_DIAGNOSTICS": "0"]))
        assert(reloaded.launchMode == .warpLab && reloaded.inputDiagnostics && reloaded.performanceOverlay)
        reloaded.performanceOverlay = false
        assert(!DeveloperSettings(defaults: defaults).performanceOverlay)
        defaults.set("unknown", forKey: "developer.launchMode")
        assert(reloaded.launchMode == .normal)
        assert(Set(LaunchMode.allCases.map { $0.rawValue }).count == 5)
        print("Developer launch defaults, persistence, override isolation and invalid-value recovery passed.")
    }
}
