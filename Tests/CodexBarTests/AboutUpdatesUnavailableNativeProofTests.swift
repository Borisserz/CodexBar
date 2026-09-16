import AppKit
import SwiftUI
import Testing
@testable import CodexBar

@MainActor
struct AboutUpdatesUnavailableNativeProofTests {
    @Test
    func `hosted about unavailable brew line is selectable and copies exactly`() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["CODEXBAR_ABOUT_BREW_NATIVE_PROOF"] == "1" else {
            // Opt-in: avoids clearing a developer's general pasteboard in ordinary suite runs.
            return
        }

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
        let textFields = allViews.compactMap { $0 as? NSTextField }
        let matchingFields = textFields.filter { $0.stringValue.contains(brewCommand) }
        let textViews = allViews.compactMap { $0 as? NSTextView }
        let matchingTextViews = textViews.filter { $0.string.contains(brewCommand) }

        #expect(
            !matchingTextViews.isEmpty || !matchingFields.isEmpty,
            "Missing brew instruction view in hosted About pane")

        let pasteboard = NSPasteboard.general
        let savedItems = pasteboard.pasteboardItems?.compactMap { item -> [NSPasteboard.PasteboardType: Data]? in
            var payload: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    payload[type] = data
                }
            }
            return payload.isEmpty ? nil : payload
        } ?? []
        defer {
            pasteboard.clearContents()
            if !savedItems.isEmpty {
                pasteboard.writeObjects(savedItems.map { payload in
                    let item = NSPasteboardItem()
                    for (type, data) in payload {
                        item.setData(data, forType: type)
                    }
                    return item
                })
            }
        }

        pasteboard.clearContents()
        let changeCountBeforeCopy = pasteboard.changeCount

        if let textView = matchingTextViews.first {
            #expect(textView.isSelectable)
            #expect(!textView.isEditable)
            window.makeFirstResponder(textView)
            textView.selectAll(nil)
            #expect(textView.selectedRange().length == textView.string.utf16.count)
            textView.copy(nil)
        } else {
            let field = try #require(matchingFields.first)
            #expect(field.isSelectable)
            window.makeFirstResponder(field)
            field.selectText(nil)
            let editor = try #require(
                field.currentEditor() as? NSTextView,
                "NSTextField must expose a field editor so copy is a real native selection operation")
            #expect(editor.isSelectable)
            editor.selectAll(nil)
            #expect(editor.selectedRange().length == editor.string.utf16.count)
            editor.copy(nil)
        }

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        #expect(pasteboard.changeCount > changeCountBeforeCopy)
        let copied = try #require(pasteboard.string(forType: .string))
        #expect(copied == brewReason)
        #expect(copied.contains(brewCommand))

        if let proofPath = environment["CODEXBAR_ABOUT_BREW_PROOF_PATH"] {
            let proofURL = URL(fileURLWithPath: proofPath)
            try FileManager.default.createDirectory(
                at: proofURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            let notePath = proofURL.deletingPathExtension().appendingPathExtension("txt")
            try """
            copied=\(copied)
            brewCommand=\(brewCommand)
            selectedVia=\(matchingTextViews.isEmpty ? "NSTextField.fieldEditor.copy" : "NSTextView.copy")
            pasteboardChangeCountDelta=\(pasteboard.changeCount - changeCountBeforeCopy)
            """.write(to: notePath, atomically: true, encoding: .utf8)

            if let view = window.contentView,
               let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)
            {
                view.cacheDisplay(in: view.bounds, to: rep)
                let image = NSImage(size: view.bounds.size)
                image.addRepresentation(rep)
                if let tiff = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiff),
                   let png = bitmap.representation(using: .png, properties: [:])
                {
                    try png.write(to: proofURL)
                }
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
