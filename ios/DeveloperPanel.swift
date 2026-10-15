import UIKit

final class DeveloperPanel: UITableViewController {
    private let settings: DeveloperSettings
    private let runningScene: String
    private let overridden: Bool
    var onDone: (() -> Void)?

    init(settings: DeveloperSettings, runningScene: String, overridden: Bool) {
        self.settings = settings
        self.runningScene = runningScene
        self.overridden = overridden
        super.init(style: .insetGrouped)
        title = "Developer"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.accessibilityIdentifier = "developer.panel"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "developer.done"
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 2 }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        if indexPath.row == 0 {
            cell.textLabel?.text = "Launch mode"
            cell.detailTextLabel?.text = settings.launchMode.title
            cell.accessoryType = .disclosureIndicator
            cell.accessibilityIdentifier = "developer.launch-mode"
        } else {
            cell.textLabel?.text = "Input diagnostics"
            cell.selectionStyle = .none
            let toggle = UISwitch()
            toggle.isOn = settings.inputDiagnostics
            toggle.accessibilityLabel = "Input diagnostics"
            toggle.accessibilityIdentifier = "developer.input-diagnostics"
            toggle.addTarget(self, action: #selector(diagnosticsChanged(_:)), for: .valueChanged)
            cell.accessoryView = toggle
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { "Next launch" }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let current = LaunchMode(rawValue: runningScene.isEmpty ? "normal" : runningScene)?.title ?? runningScene
        return "Force-close and reopen to apply changes. Experiments use disposable characters.\n\nRunning: \(current). Game paused while this panel is open."
            + (overridden ? "\nLaunch environment overrides are active for this run." : "")
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row == 0 { navigationController?.pushViewController(LaunchModePicker(settings: settings), animated: true) }
    }

    @objc private func diagnosticsChanged(_ sender: UISwitch) { settings.inputDiagnostics = sender.isOn }
    @objc private func done() { onDone?() }
}

private final class LaunchModePicker: UITableViewController {
    private let settings: DeveloperSettings

    init(settings: DeveloperSettings) {
        self.settings = settings
        super.init(style: .insetGrouped)
        title = "Launch mode"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { LaunchMode.allCases.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let mode = LaunchMode.allCases[indexPath.row]
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = mode.title
        cell.accessoryType = settings.launchMode == mode ? .checkmark : .none
        cell.accessibilityIdentifier = "developer.mode.\(mode.rawValue)"
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        settings.launchMode = LaunchMode.allCases[indexPath.row]
        navigationController?.popViewController(animated: true)
    }
}

final class DeveloperWindow: UIWindow {
    var onShake: (() -> Void)?
    override var canBecomeFirstResponder: Bool { true }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake { onShake?() } else { super.motionEnded(motion, with: event) }
    }
}
