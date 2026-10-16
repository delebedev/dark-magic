import Foundation

@main
struct GameErrorSummaryTests {
    static func main() {
        let cause = "assigned skill has not migrated to d2legacy: 2 side=right"
        let path = "@mods/d2legacy/lua/d2legacy/commands/cast.lua"
        func report(_ sequence: Int, _ line: Int) -> GameErrorSummary {
            GameErrorSummary("admitted command failed: player.use_skill player=\"local-player\" sequence=\(sequence): \(path):\(line): \(cause)\nstack traceback:\n\t[G]: in function 'assert'")
        }
        let first = report(210, 91)
        assert(first.type == "LuaError" && first.message == cause && first.source == path)
        assert(first.fingerprint == report(328, 95).fingerprint)
        let different = GameErrorSummary("\(path):91: context deadline exceeded")
        assert(first.fingerprint != different.fingerprint)
        let otherSource = GameErrorSummary("@mods/d2legacy/lua/other.lua:91: \(cause)")
        assert(first.fingerprint != otherSource.fingerprint)
        let go = GameErrorSummary("asset configuration failed\nadditional detail")
        assert(go.type == "GameError" && go.message == "asset configuration failed" && go.source == nil)
        print("Game error causes group independently of command sequence and source line.")
    }
}
