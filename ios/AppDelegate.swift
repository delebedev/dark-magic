import UIKit
import Sentry
import Darkmagicmobile

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, UIPopoverPresentationControllerDelegate {
    var window: UIWindow?
    private var gameController: GameViewController?
    private let developerSettings = DeveloperSettings()
    private var developerPanelOpen = false
    private var textInputOpen = false
    private var textInput: NativeTextInput?
    private var runningScene = ""
    private var launchOverrides = false

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if let dsn = Bundle.main.object(forInfoDictionaryKey: "SentryDSN") as? String, !dsn.isEmpty {
            let revision = Bundle.main.url(forResource: "build-revision", withExtension: "txt")
                .flatMap { try? String(contentsOf: $0, encoding: .utf8) }?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
            SentrySDK.start { options in
                options.dsn = dsn
                options.releaseName = "org.darkmagic.experimental@0.1+\(revision)"
                options.environment = "ios-iteration"
                options.beforeSend = { event in
                    guard let error = event.error as NSError?, error.domain == "go",
                          let exception = event.exceptions?.last else { return event }
                    let summary = GameErrorSummary(error.localizedDescription)
                    exception.type = summary.type
                    exception.value = summary.message
                    event.fingerprint = summary.fingerprint
                    if let source = summary.source {
                        var tags = event.tags ?? [:]
                        tags["lua_source"] = source
                        event.tags = tags
                    }
                    return event
                }
                options.sendDefaultPii = false
                options.tracesSampleRate = 0
                options.enableAutoSessionTracking = false
                options.enableAppHangTracking = false
                options.enableAutoBreadcrumbTracking = false
                options.attachScreenshot = false
                options.attachViewHierarchy = false
            }
        }
        let window = DeveloperWindow(frame: UIScreen.main.bounds)
        self.window = window
        window.onShake = { [weak self] in self?.showDeveloperPanel() }
        let environment = ProcessInfo.processInfo.environment
        runningScene = developerSettings.resolvedScene(environment: environment)
        SentrySDK.configureScope { scope in
            scope.setTag(value: self.runningScene, key: "launch_scene")
        }
        launchOverrides = environment["DARK_MAGIC_START_SCENE"] != nil || environment["DARK_MAGIC_INPUT_DIAGNOSTICS"] != nil
        let diagnostics = developerSettings.resolvedDiagnostics(environment: environment)
        setenv("DARK_MAGIC_INPUT_DIAGNOSTICS", diagnostics ? "1" : "0", 1)
        let textInput = NativeTextInput()
        textInput.present = { [weak self] alert in
            guard let self = self, UIApplication.shared.applicationState == .active,
                  !self.developerPanelOpen, !self.textInputOpen,
                  let root = self.window?.rootViewController, root.presentedViewController == nil else { return false }
            self.textInputOpen = true
            self.gameController?.view.isUserInteractionEnabled = false
            self.gameController?.suspendGame()
            root.present(alert, animated: true)
            return true
        }
        textInput.finished = { [weak self] in
            guard let self = self, self.textInputOpen else { return }
            self.textInputOpen = false
            self.gameController?.view.isUserInteractionEnabled = true
            if UIApplication.shared.applicationState == .active { self.gameController?.resumeGame() }
            self.window?.becomeFirstResponder()
        }
        self.textInput = textInput
        DarkmagicmobileSetTextInputHandler(textInput)
        prepareGame(scene: runningScene)
        window.makeKeyAndVisible()
        window.becomeFirstResponder()
        return true
    }

    private func prepareGame(scene: String) {
        showLaunchMessage("Preparing game assets…")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let files = FileManager.default
                let support = try files.url(for: .applicationSupportDirectory,
                    in: .userDomainMask, appropriateFor: nil, create: true)
                    .appendingPathComponent("DarkMagic", isDirectory: true)
                let documents = try files.url(for: .documentDirectory,
                    in: .userDomainMask, appropriateFor: nil, create: true)
                    .appendingPathComponent("Assets", isDirectory: true)
                let bundled = Bundle.main.resourceURL!.appendingPathComponent("Assets", isDirectory: true)
                let assets = DarkmagicmobileRequiresGameAssets()
                    ? try GameAssets.prepare(documents: documents, bundled: bundled) : documents
                DispatchQueue.main.async { self?.startGame(scene: scene, assets: assets, support: support) }
            } catch {
                DispatchQueue.main.async { self?.showStartupError(error) }
            }
        }
    }

    private func startGame(scene: String, assets: URL, support: URL) {
        guard let window = window else { return }
        do {
            var error: NSError?
            #if targetEnvironment(simulator)
            let nativeAudio = false
            #else
            let nativeAudio = true
            #endif
            guard DarkmagicmobileConfigure(assets.path, support.path, scene, nativeAudio, &error) else {
                throw error ?? NSError(domain: "DarkMagic", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Asset configuration failed"])
            }
            let controller = GameViewController()
            gameController = controller
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
            } else {
                window.rootViewController = controller
            }
            if UIApplication.shared.applicationState != .active { controller.suspendGame() }
        } catch {
            showStartupError(error)
        }
    }

    private func showStartupError(_ error: Error) {
        SentrySDK.capture(error: error) { scope in scope.setTag(value: "startup", key: "failure_phase") }
        showLaunchMessage("Dark Magic could not start.\n\n\(error.localizedDescription)\n\nCopy the complete LoD archive set into Documents/Assets, or install and launch a seed build once.")
    }

    private func showLaunchMessage(_ message: String) {
        let controller = UIViewController()
        controller.view.backgroundColor = .black
        let label = UILabel()
        label.textColor = .white
        label.numberOfLines = 0
        label.text = message
        label.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            label.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor)
        ])
        window?.rootViewController = controller
    }

    func applicationWillResignActive(_ application: UIApplication) { gameController?.suspendGame() }
    func applicationDidBecomeActive(_ application: UIApplication) {
        if !developerPanelOpen && !textInputOpen { gameController?.resumeGame() }
    }

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle { .none }
    func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool { false }

    // Shake and debugger invocation share this presenter and its pause ownership.
    @objc func showDeveloperPanel() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.showDeveloperPanel() }
            return
        }
        guard gameController != nil, !developerPanelOpen, UIApplication.shared.applicationState == .active,
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
