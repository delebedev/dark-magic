import UIKit
import Darkmagicmobile

// These buttons emit the same logical actions as desktop hotkeys.
final class WorldActionsView: UIStackView {
    private let status = UILabel()
    private weak var controller: UIViewController?

    init(controller: UIViewController) {
        self.controller = controller
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        spacing = 8
        alignment = .center
        backgroundColor = UIColor.black.withAlphaComponent(0.75)
        layer.cornerRadius = 8
        isLayoutMarginsRelativeArrangement = true
        layoutMargins = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        let back = UIButton(type: .system)
        back.setTitle("Back", for: .normal)
        back.accessibilityHint = "Close the current game panel or open pause"
        back.addTarget(self, action: #selector(closePanel), for: .touchUpInside)
        let panels = UIButton(type: .system)
        panels.setTitle("Tools", for: .normal)
        panels.addTarget(self, action: #selector(choosePanel(_:)), for: .touchUpInside)
        for button in [back, panels] {
            button.heightAnchor.constraint(equalToConstant: 44).isActive = true
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 64).isActive = true
            addArrangedSubview(button)
        }
        status.font = .preferredFont(forTextStyle: .caption2)
        status.textColor = .systemRed
        status.isHidden = true
        addArrangedSubview(status)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func closePanel() { send("cancel") }

    @objc private func choosePanel(_ sender: UIButton) {
        let menu = UIAlertController(title: "Diagnostics", message: nil, preferredStyle: .actionSheet)
        for (title, action) in [
            ("Inventory", "inventory"), ("Character", "character"), ("Skills", "skills"),
            ("Quests", "quests"), ("Map", "automap"), ("Options", "options"),
            ("Help", "help"), ("Run / walk", "toggle_run"), ("Swap weapons", "swap_weapons")
        ] {
            menu.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in self?.send(action) })
        }
        menu.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        menu.popoverPresentationController?.sourceView = sender
        menu.popoverPresentationController?.sourceRect = sender.bounds
        controller?.present(menu, animated: true)
    }

    private func send(_ action: String) {
        var error: NSError?
        let sent = DarkmagicmobilePressAction(action, &error)
        status.text = sent ? nil : error?.localizedDescription
        status.isHidden = sent
        if !sent { UIAccessibility.post(notification: .announcement, argument: status.text) }
    }
}

// Diagnostic taps enter the ordinary frame input path, not gameplay commands.
final class TapProbeView: UIStackView {
    private let x = UITextField()
    private let y = UITextField()
    private let status = UILabel()
    private var collapsed = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        axis = .vertical
        spacing = 4
        backgroundColor = UIColor.black.withAlphaComponent(0.8)
        layer.cornerRadius = 8
        isLayoutMarginsRelativeArrangement = true
        layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        let toggle = UIButton(type: .system)
        toggle.setTitle("Hide probes", for: .normal)
        toggle.addTarget(self, action: #selector(toggleProbe(_:)), for: .touchUpInside)
        toggle.heightAnchor.constraint(equalToConstant: 44).isActive = true
        addArrangedSubview(toggle)
        let fields = UIStackView()
        fields.axis = .horizontal
        fields.spacing = 4
        fields.distribution = .fillEqually
        addArrangedSubview(fields)
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
            fields.addArrangedSubview(field)
        }
        let tap = UIButton(type: .system)
        tap.setTitle("Probe tap", for: .normal)
        tap.addTarget(self, action: #selector(submit), for: .touchUpInside)
        tap.heightAnchor.constraint(equalToConstant: 44).isActive = true
        addArrangedSubview(tap)
        var row = UIStackView()
        for (index, title) in ["Move east", "Hold main", "Move + main", "Aim second", "Cancel second", "Third skill"].enumerated() {
            if index % 2 == 0 {
                row = UIStackView()
                row.axis = .horizontal
                row.distribution = .fillEqually
                row.spacing = 4
                addArrangedSubview(row)
            }
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.tag = index
            button.addTarget(self, action: #selector(gesture(_:)), for: .touchUpInside)
            button.heightAnchor.constraint(equalToConstant: 44).isActive = true
            row.addArrangedSubview(button)
        }
        status.text = "Logical pixels"
        status.textColor = .lightGray
        status.font = .preferredFont(forTextStyle: .caption2)
        status.numberOfLines = 0
        addArrangedSubview(status)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func toggleProbe(_ sender: UIButton) {
        collapsed.toggle()
        for view in arrangedSubviews where view !== sender { view.isHidden = collapsed }
        sender.setTitle(collapsed ? "Show probes" : "Hide probes", for: .normal)
    }

    @objc private func gesture(_ sender: UIButton) {
        endEditing(true)
        let width = Double(DarkmagicmobileLogicalWidth())
        guard width > 0 else { status.text = "Game is loading"; return }
        let host = window?.rootViewController?.view
        let scale = 600 / Double(host?.bounds.height ?? 402)
        let safe = host?.safeAreaInsets ?? .zero
        let moveX = max(152, Double(safe.left)*scale + 88 + 10*scale)
        func padX(_ inset: Double, _ radius: Double) -> Double {
            min(width-inset, width-Double(safe.right)*scale-radius-10*scale)
        }
        func point(_ id: Int, _ x: Double, _ y: Double) -> [String: Any] { ["ID": id, "X": x, "Y": y] }
        var start: [[String: Any]] = []
        var held: [[String: Any]] = []
        switch sender.tag {
        case 0:
            start = [point(1,moveX,406)]; held = [point(1,moveX+58,406)]
        case 1:
            start = [point(2,padX(152,66),406)]; held = start
        case 2:
            start = [point(1,moveX,406),point(2,padX(152,66),406)]
            held = [point(1,moveX+58,406),point(2,padX(152,66),406)]
        case 3:
            start = [point(2,padX(264,46),308)]; held = [point(2,padX(264,46)-40,278)]
        case 4:
            start = [point(2,padX(264,46),308)]; held = [point(2,padX(264,46)-200,308)]
        default:
            start = [point(2,padX(146,46),264)]; held = start
        }
        var steps: [[String: Any]] = [["Frames": 1, "Contacts": start],
            ["Frames": sender.tag < 3 ? 120 : 30, "Contacts": held],
            ["Frames": 1, "Contacts": []]]
        if sender.tag == 2 {
            steps = [["Frames": 1, "Contacts": [point(1,moveX,406)]],
                ["Frames": 35, "Contacts": [point(1,moveX+58,406)]],
                ["Frames": 120, "Contacts": held],
                ["Frames": 45, "Contacts": [point(1,moveX+58,406)]],
                ["Frames": 1, "Contacts": []]]
        }
        do {
            let json = String(data: try JSONSerialization.data(withJSONObject: steps), encoding: .utf8)!
            var error: NSError?
            status.text = DarkmagicmobileProbeContacts(json, &error) ? "Queued gesture" : error?.localizedDescription
        } catch { status.text = error.localizedDescription }
    }

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
