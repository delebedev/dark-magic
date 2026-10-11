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
            if ProcessInfo.processInfo.environment["DARK_MAGIC_INPUT_DIAGNOSTICS"] == "1" {
                let host = UIViewController()
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
                let probe = TapProbeView()
                host.view.addSubview(probe)
                NSLayoutConstraint.activate([
                    probe.leadingAnchor.constraint(equalTo: host.view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
                    probe.topAnchor.constraint(equalTo: host.view.safeAreaLayoutGuide.topAnchor, constant: 80),
                    probe.widthAnchor.constraint(equalToConstant: 110)
                ])
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

private final class ScenePickerViewController: UIViewController {
    private let scenes = [
        ("Town · Amazon movement", "game_world"),
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

// Diagnostic taps enter the ordinary frame input path, not gameplay commands.
private final class TapProbeView: UIStackView {
    private let x = UITextField()
    private let y = UITextField()
    private let status = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        axis = .vertical
        spacing = 4
        backgroundColor = UIColor.black.withAlphaComponent(0.8)
        layer.cornerRadius = 8
        isLayoutMarginsRelativeArrangement = true
        layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        for (field, name, value) in [(x, "Probe X", "700"), (y, "Probe Y", "380")] {
            field.accessibilityLabel = name
            field.placeholder = name
            let axis = UILabel(frame: CGRect(x: 0, y: 0, width: 18, height: 20))
            axis.text = String(name.suffix(1))
            axis.textColor = .lightGray
            axis.textAlignment = .center
            field.leftView = axis
            field.leftViewMode = .always
            field.text = value
            field.textColor = .white
            field.borderStyle = .roundedRect
            field.backgroundColor = .darkGray
            field.keyboardType = .numberPad
            field.heightAnchor.constraint(equalToConstant: 44).isActive = true
            addArrangedSubview(field)
        }
        let tap = UIButton(type: .system)
        tap.setTitle("Probe tap", for: .normal)
        tap.addTarget(self, action: #selector(submit), for: .touchUpInside)
        tap.heightAnchor.constraint(equalToConstant: 44).isActive = true
        addArrangedSubview(tap)
        status.text = "Logical pixels"
        status.textColor = .lightGray
        status.font = .preferredFont(forTextStyle: .caption2)
        status.numberOfLines = 0
        addArrangedSubview(status)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func submit() {
        endEditing(true)
        guard let px = Int(x.text ?? ""), let py = Int(y.text ?? "") else {
            status.text = "Enter integer X/Y"
            return
        }
        var error: NSError?
        status.text = DarkmagicmobileProbeTap(px, py, &error)
            ? "Queued \(px),\(py)" : (error?.localizedDescription ?? "Probe failed")
    }
}
