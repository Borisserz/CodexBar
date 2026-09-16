import Foundation
import Testing
@testable import CodexBar

@MainActor
struct AboutUpdatesUnavailableContentTests {
    @Test
    func `unavailable update reason keeps the brew command and enables text selection`() throws {
        let brewReason = "Updates managed by Homebrew. Run: brew upgrade --cask steipete/tap/codexbar"

        #expect(AboutUpdatesUnavailableContent.message(unavailableReason: brewReason) == brewReason)
        #expect(AboutUpdatesUnavailableContent.message(unavailableReason: nil) == L("updates_unavailable"))
        #expect(AboutUpdatesUnavailableContent.allowsTextSelection)

        let source = try String(
            contentsOf: Self.repoRoot().appendingPathComponent("Sources/CodexBar/PreferencesAboutPane.swift"),
            encoding: .utf8)
        #expect(source.contains("AboutUpdatesUnavailableContent.message(unavailableReason:"))
        #expect(source.contains(".textSelection(.enabled)"))

        _ = AboutPane(updater: DisabledUpdaterController(unavailableReason: brewReason)).body
    }

    private static func repoRoot() throws -> URL {
        var directory = URL(filePath: #filePath).deletingLastPathComponent()
        for _ in 0..<12 {
            if FileManager.default.fileExists(
                atPath: directory.appending(path: "Package.swift").path(percentEncoded: false))
            {
                return directory
            }
            directory.deleteLastPathComponent()
        }
        throw CocoaError(.fileNoSuchFile)
    }
}
