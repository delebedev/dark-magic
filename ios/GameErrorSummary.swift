import Foundation

// Group Lua failures by their source and cause, excluding command sequence wrappers.
struct GameErrorSummary {
    let type: String
    let message: String
    let source: String?
    var fingerprint: [String] { [type, source ?? "", message] }

    private static let location = try! NSRegularExpression(
        pattern: #"(@[^\s:]+\.lua):[0-9]+: ([^\n]+)"#)

    init(_ detail: String) {
        let text = detail as NSString
        if let match = Self.location.firstMatch(in: detail, range: NSRange(location: 0, length: text.length)) {
            type = "LuaError"
            source = text.substring(with: match.range(at: 1))
            message = text.substring(with: match.range(at: 2))
        } else {
            type = "GameError"
            source = nil
            message = detail.components(separatedBy: "\n").first ?? detail
        }
    }
}
