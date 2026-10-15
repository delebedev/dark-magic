import UIKit
import Darkmagicmobile

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, UIPopoverPresentationControllerDelegate {
    var window: UIWindow?
    private var gameController: GameViewController?
    private let developerSettings = DeveloperSettings()
    private var developerPanelOpen = false
    private var runningScene = ""
    private var launchOverrides = false

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = DeveloperWindow(frame: UIScreen.main.bounds)
        self.window = window
        window.onShake = { [weak self] in self?.showDeveloperPanel() }
        let environment = ProcessInfo.processInfo.environment
        runningScene = developerSettings.resolvedScene(environment: environment)
        launchOverrides = environment["DARK_MAGIC_START_SCENE"] != nil || environment["DARK_MAGIC_INPUT_DIAGNOSTICS"] != nil
        let diagnostics = developerSettings.resolvedDiagnostics(environment: environment)
        setenv("DARK_MAGIC_INPUT_DIAGNOSTICS", diagnostics ? "1" : "0", 1)
        startGame(scene: runningScene)
        window.makeKeyAndVisible()
        window.becomeFirstResponder()
        return true
    }

    private func startGame(scene: String) {
        guard let window = window else { return }
        do {
            let support = try FileManager.default.url(for: .applicationSupportDirectory,
                in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("DarkMagic", isDirectory: true)
            let documents = try FileManager.default.url(for: .documentDirectory,
                in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("Assets", isDirectory: true)
            let bundled = Bundle.main.resourceURL!.appendingPathComponent("Assets", isDirectory: true)
            var isDirectory: ObjCBool = false
            let hasImportedAssets = FileManager.default.fileExists(atPath: documents.path, isDirectory: &isDirectory)
                && isDirectory.boolValue
            let assets = hasImportedAssets ? documents : bundled
            var error: NSError?
            guard DarkmagicmobileConfigure(assets.path, support.path, scene, &error) else {
                throw error ?? NSError(domain: "DarkMagic", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Asset configuration failed"])
            }
            let controller = GameViewController()
            gameController = controller
            window.rootViewController = controller
            if scene != "ui_lab" || ProcessInfo.processInfo.environment["DARK_MAGIC_INPUT_DIAGNOSTICS"] == "1" {
                let host = GameHostViewController()
                host.addChild(controller)
                controller.view.translatesAutoresizingMaskIntoConstraints = false
                host.view.addSubview(controller.view)
                NSLayoutConstraint.activate([
                    controller.view.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
                    controller.view.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
                    controller.view.topAnchor.constraint(equalTo: host.view.topAnchor),
                    controller.view.bottomAnchor.constraint(equalTo: host.view.bottomAnchor)
                ])
                controller.didMove(toParent: host)
                if scene != "ui_lab" && ProcessInfo.processInfo.environment["DARK_MAGIC_INPUT_DIAGNOSTICS"] == "1" {
                    let controls = WorldActionsView(controller: host)
                    host.view.addSubview(controls)
                    NSLayoutConstraint.activate([
                        controls.trailingAnchor.constraint(equalTo: host.view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
                        controls.topAnchor.constraint(equalTo: host.view.safeAreaLayoutGuide.topAnchor, constant: 8)
                    ])
                }
                if ProcessInfo.processInfo.environment["DARK_MAGIC_INPUT_DIAGNOSTICS"] == "1" {
                    let probe = TapProbeView()
                    host.view.addSubview(probe)
                    NSLayoutConstraint.activate([
                        probe.leadingAnchor.constraint(equalTo: host.view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
                        probe.topAnchor.constraint(equalTo: host.view.safeAreaLayoutGuide.topAnchor, constant: 48),
                        probe.widthAnchor.constraint(equalToConstant: 210)
                    ])
                }
                window.rootViewController = host
            }
        } catch {
            let controller = UIViewController()
            controller.view.backgroundColor = .black
            let label = UILabel()
            label.textColor = .white
            label.numberOfLines = 0
            label.text = "Dark Magic could not start.\n\n\(error.localizedDescription)\n\nCopy original LoD MPQs into Documents/Assets, or bundle ios/Assets."
            label.translatesAutoresizingMaskIntoConstraints = false
            controller.view.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
                label.trailingAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
                label.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor)
            ])
            window.rootViewController = controller
        }
    }

    func applicationWillResignActive(_ application: UIApplication) { gameController?.suspendGame() }
    func applicationDidBecomeActive(_ application: UIApplication) {
        if !developerPanelOpen { gameController?.resumeGame() }
    }

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle { .none }
    func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool { false }

    // Shake and debugger invocation share this presenter and its pause ownership.
    @objc func showDeveloperPanel() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.showDeveloperPanel() }
            return
        }
        guard !developerPanelOpen, UIApplication.shared.applicationState == .active,
              let root = window?.rootViewController, root.presentedViewController == nil else { return }
        developerPanelOpen = true
        // Disabling interaction cancels UIKit touches before the native loop is suspended.
        gameController?.view.isUserInteractionEnabled = false
        gameController?.suspendGame()
        let panel = DeveloperPanel(settings: developerSettings, runningScene: runningScene, overridden: launchOverrides)
        let navigation = UINavigationController(rootViewController: panel)
        navigation.overrideUserInterfaceStyle = .dark
        navigation.modalPresentationStyle = .popover
        navigation.preferredContentSize = CGSize(width: 560, height: 330)
        if let popover = navigation.popoverPresentationController {
            popover.sourceView = root.view
            popover.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
            popover.delegate = self
        }
        navigation.isModalInPresentation = true
        panel.onDone = { [weak self, weak navigation] in
            navigation?.dismiss(animated: true) {
                guard let self = self else { return }
                self.developerPanelOpen = false
                self.gameController?.view.isUserInteractionEnabled = true
                if UIApplication.shared.applicationState == .active { self.gameController?.resumeGame() }
                self.window?.becomeFirstResponder()
            }
        }
        root.present(navigation, animated: true)
    }
}

private final class GameHostViewController: UIViewController {
    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = view.bounds.size
        let safe = view.safeAreaInsets
        guard size.width > 0 && size.height > 0 else { return }
        var error: NSError?
        if !DarkmagicmobileSetScreenGeometry(Double(size.width), Double(size.height),
            Double(safe.left), Double(safe.top), Double(safe.right), Double(safe.bottom), &error) {
            NSLog("Dark Magic geometry: %@", error?.localizedDescription ?? "invalid geometry")
        }
    }
}
