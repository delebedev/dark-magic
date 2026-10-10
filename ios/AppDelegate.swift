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
            guard DarkmagicmobileConfigure(assets.path, support.path, &error) else {
                throw error ?? NSError(domain: "DarkMagic", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Asset configuration failed"])
            }
            let controller = GameViewController()
            gameController = controller
            window.rootViewController = controller
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
        window.makeKeyAndVisible()
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) { gameController?.suspendGame() }
    func applicationDidBecomeActive(_ application: UIApplication) { gameController?.resumeGame() }
}
