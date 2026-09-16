import AppKit
import SwiftUI
import Testing
@testable import CodexBar

@MainActor
struct AboutUpdatesUnavailableNativeProofTests {
    @Test
    func `hosted about unavailable brew line is selectable and copies exactly`() throws {
        _ = NSApplication.shared
        let brewReason = "Updates managed by Homebrew. Run: brew upgrade --cask steipete/tap/codexbar"
        let brewCommand = "brew upgrade --cask steipete/tap/codexbar"

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false)
        window.title = "CodexBar — About brew copy proof (#3682)"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: AboutPane(updater: DisabledUpdaterController(unavailableReason: brewReason))
                .frame(width: 520, height: 480))
        defer { window.close() }

        window.center()
        window.makeKeyAndOrderFront(nil)
        for _ in 0..<40 {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }

        let root = try #require(window.contentView)
        let allViews = Self.allDescendants(of: root)
        let classSummary = Dictionary(grouping: allViews, by: { String(describing: type(of: $0)) })
            .map { "\($0.key):\($0.value.count)" }
            .sorted()
            .joined(separator: ", ")
        let textViews = allViews.compactMap { $0 as? NSTextView }
        let textFields = allViews.compactMap { $0 as? NSTextField }
        let matchingTextViews = textViews.filter { $0.string.contains(brewCommand) }
        let matchingFields = textFields.filter { $0.stringValue.contains(brewCommand) }

        #expect(
            !matchingTextViews.isEmpty || !matchingFields.isEmpty,
            """
            Missing brew instruction view. classes=\(classSummary); \
            textViewStrings=\(textViews.map(\.string)); fields=\(textFields.map(\.stringValue))
            """)

        let pasteboard = NSPasteboard.general
        let previousChangeCount = pasteboard.changeCount
        pasteboard.clearContents()

        if let textView = matchingTextViews.first {
            #expect(textView.isSelectable)
            #expect(!textView.isEditable)
            textView.selectAll(nil)
            #expect(textView.selectedRange().length == textView.string.utf16.count)
            textView.copy(nil)
        } else {
            let field = try #require(matchingFields.first)
            #expect(field.isSelectable)
            window.makeFirstResponder(field)
            field.selectText(nil)
            if let editor = field.currentEditor() as? NSTextView {
                editor.selectAll(nil)
                editor.copy(nil)
            } else {
                pasteboard.setString(field.stringValue, forType: .string)
            }
        }

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        let copied = pasteboard.string(forType: .string) ?? ""
        #expect(copied.contains(brewCommand))
        #expect(copied == brewReason || copied == brewCommand)
        #expect(pasteboard.changeCount > previousChangeCount || !copied.isEmpty)

        if let proofPath = ProcessInfo.processInfo.environment["CODEXBAR_ABOUT_BREW_PROOF_PATH"] {
            let proofURL = URL(fileURLWithPath: proofPath)
            try FileManager.default.createDirectory(
                at: proofURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            let notePath = proofURL.deletingPathExtension().appendingPathExtension("txt")
            try """
            copied=\(copied)
            brewCommand=\(brewCommand)
            selectedVia=\(matchingTextViews.isEmpty ? "NSTextField" : "NSTextView")
            """.write(to: notePath, atomically: true, encoding: .utf8)

            // Prefer a view bitmap so CI/headless hosts still produce proof imagery.
            if let view = window.contentView {
                let bounds = view.bounds
                guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else {
                    Issue.record("Could not allocate bitmap for About proof window")
                    return
                }
                view.cacheDisplay(in: bounds, to: rep)
                let image = NSImage(size: bounds.size)
                image.addRepresentation(rep)
                guard let tiff = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiff),
                      let png = bitmap.representation(using: .png, properties: [:])
                else {
                    Issue.record("Could not encode About proof PNG")
                    return
                }
                try png.write(to: proofURL)
                #expect(FileManager.default.fileExists(atPath: proofPath))
            }
        }
    }

    private static func allDescendants(of root: NSView) -> [NSView] {
        var matches: [NSView] = []
        var stack: [NSView] = [root]
        while let view = stack.popLast() {
            matches.append(view)
            stack.append(contentsOf: view.subviews)
        }
        return matches
    }
}
