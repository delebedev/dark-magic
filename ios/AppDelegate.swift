import UIKit
import Darkmagicmobile

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private var gameController: GameViewController?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window
        if let scene = ProcessInfo.processInfo.environment["DARK_MAGIC_START_SCENE"], !scene.isEmpty {
            startGame(scene: scene)
        } else {
            window.rootViewController = ScenePickerViewController { [weak self] scene in
                self?.startGame(scene: scene)
            }
        }
        window.makeKeyAndVisible()
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
    func applicationDidBecomeActive(_ application: UIApplication) { gameController?.resumeGame() }
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

private final class ScenePickerViewController: UIViewController {
    private let scenes = [
        ("Game World · Amazon", "game_world"),
        ("Spell Lab · Sorceress in Blood Moor", "spell_lab"),
        ("Warp Lab · Town and wilderness portals", "warp_lab"),
        ("UI Lab · Buttons and slider", "ui_lab")
    ]
    private let selectScene: (String) -> Void

    init(selectScene: @escaping (String) -> Void) {
        self.selectScene = selectScene
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        let title = UILabel()
        title.text = "Dark Magic · Experiments"
        title.font = .preferredFont(forTextStyle: .title2)
        title.textColor = .white
        stack.addArrangedSubview(title)
        for (index, scene) in scenes.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(scene.0, for: .normal)
            button.contentHorizontalAlignment = .leading
            button.titleLabel?.font = .preferredFont(forTextStyle: .body)
            button.tag = index
            button.addTarget(self, action: #selector(chooseScene(_:)), for: .touchUpInside)
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            stack.addArrangedSubview(button)
        }
        let hint = UILabel()
        hint.text = "Disposable characters. Force-close and reopen to choose another scene."
        hint.font = .preferredFont(forTextStyle: .footnote)
        hint.textColor = .lightGray
        hint.numberOfLines = 0
        stack.addArrangedSubview(hint)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func chooseScene(_ sender: UIButton) {
        selectScene(scenes[sender.tag].1)
    }
}
