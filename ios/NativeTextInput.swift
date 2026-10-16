import UIKit
import Darkmagicmobile

final class NativeTextInput: NSObject, DarkmagicmobileTextInputHandlerProtocol, UITextFieldDelegate {
    var present: ((UIAlertController) -> Bool)?
    var finished: (() -> Void)?
    private var alert: UIAlertController?
    private var requestID: Int64?

    func editText(_ id: Int64, value: String?, title: String?, secure: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
            alert.overrideUserInterfaceStyle = .dark
            alert.addTextField { field in
                field.text = value
                field.isSecureTextEntry = secure
                field.autocapitalizationType = .none
                field.autocorrectionType = .no
                field.spellCheckingType = .no
                field.smartQuotesType = .no
                field.smartDashesType = .no
                field.returnKeyType = .done
                field.accessibilityIdentifier = "game.text-input"
                field.delegate = self
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in self?.finish(accepted: false) })
            alert.addAction(UIAlertAction(title: "Done", style: .default) { [weak self] _ in self?.finish(accepted: true) })
            self.alert = alert
            self.requestID = id
            if self.present?(alert) != true { self.finish(accepted: false) }
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        finish(accepted: true)
        return false
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let value = textField.text ?? ""
        guard let range = Range(range, in: value) else { return false }
        return value.replacingCharacters(in: range, with: string).utf8.count <= 16384
    }

    private func finish(accepted: Bool) {
        guard let id = requestID else { return }
        var error: NSError?
        if !DarkmagicmobileCompleteTextInput(id, accepted ? alert?.textFields?.first?.text ?? "" : "", accepted, &error) {
            alert?.message = error?.localizedDescription ?? "Text could not be applied. Try again or cancel."
            return
        }
        requestID = nil
        let current = alert
        alert = nil
        if current?.presentingViewController != nil {
            current?.dismiss(animated: true) { [weak self] in self?.finished?() }
        } else {
            finished?()
        }
    }
}
