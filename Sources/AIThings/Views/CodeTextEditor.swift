import SwiftUI
import AppKit

/// A multiline editor backed by NSTextView, with a line-number gutter,
/// keyboard handling (⌘↩ send, Esc, ↑/↓ history), and image-aware paste
/// (pasted images are inserted as inline tokens at the caret).
struct CodeTextEditor: NSViewRepresentable {
    @Binding var text: String
    /// Toggling this value moves first-responder focus to the editor.
    var focusToggle: Bool

    var onSubmit: () -> Void = {}
    var onEscape: () -> Void = {}
    /// Return true to consume the arrow (history recall handled it).
    var onArrowUp: () -> Bool = { false }
    var onArrowDown: () -> Bool = { false }
    /// Called on paste; return inline tokens to insert for any pasted images,
    /// or [] to let the editor paste text normally.
    var onPasteImages: () -> [String] = { [] }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true

        let textView = KeyTextView()
        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textColor = NSColor(red: 0.914, green: 0.941, blue: 0.969, alpha: 1)
        textView.insertionPointColor = NSColor(red: 0.357, green: 0.651, blue: 0.910, alpha: 1)
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.string = text

        textView.onSubmit = onSubmit
        textView.onEscape = onEscape
        textView.onArrowUp = onArrowUp
        textView.onArrowDown = onArrowDown
        textView.onPasteImages = onPasteImages

        scrollView.documentView = textView

        let ruler = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        context.coordinator.textView = textView
        context.coordinator.ruler = ruler
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? KeyTextView else { return }
        // Keep closures fresh (they capture current state).
        textView.onSubmit = onSubmit
        textView.onEscape = onEscape
        textView.onArrowUp = onArrowUp
        textView.onArrowDown = onArrowDown
        textView.onPasteImages = onPasteImages

        if textView.string != text {
            textView.string = text
            context.coordinator.ruler?.needsDisplay = true
        }
        if focusToggle != context.coordinator.lastFocusToggle {
            context.coordinator.lastFocusToggle = focusToggle
            DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeTextEditor
        weak var textView: NSTextView?
        weak var ruler: LineNumberRulerView?
        var lastFocusToggle: Bool

        init(_ parent: CodeTextEditor) {
            self.parent = parent
            self.lastFocusToggle = parent.focusToggle
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
            ruler?.needsDisplay = true
        }
    }
}

/// NSTextView subclass that routes shortcuts and image paste to closures.
final class KeyTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onEscape: (() -> Void)?
    var onArrowUp: (() -> Bool)?
    var onArrowDown: (() -> Bool)?
    var onPasteImages: (() -> [String])?

    override func keyDown(with event: NSEvent) {
        let cmd = event.modifierFlags.contains(.command)
        switch event.keyCode {
        case 36, 76: // return / numpad enter
            if cmd { onSubmit?(); return }
        case 53: // escape
            onEscape?(); return
        case 126: // up arrow
            if onArrowUp?() == true { return }
        case 125: // down arrow
            if onArrowDown?() == true { return }
        default:
            break
        }
        super.keyDown(with: event)
    }

    /// Catch ⌘V before the Edit menu's Paste, so an image/file on the clipboard
    /// is attached (inserted as an inline token) instead of pasted as nothing.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "v" {
            if let tokens = onPasteImages?(), !tokens.isEmpty {
                insertText(tokens.joined(separator: " ") + " ", replacementRange: selectedRange())
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    override func paste(_ sender: Any?) {
        if let tokens = onPasteImages?(), !tokens.isEmpty {
            insertText(tokens.joined(separator: " ") + " ", replacementRange: selectedRange())
            return
        }
        super.paste(sender)
    }
}

/// Draws line numbers in the scroll view's vertical ruler.
final class LineNumberRulerView: NSRulerView {
    weak var textView: NSTextView?

    init(textView: NSTextView) {
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.textView = textView
        self.clientView = textView
        self.ruleThickness = 34
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor(red: 0.40, green: 0.46, blue: 0.53, alpha: 1)
        ]
        let nsString = textView.string as NSString
        let relativeY = convert(NSPoint.zero, from: textView).y
        let inset = textView.textContainerInset.height

        // Empty document still shows "1".
        if nsString.length == 0 {
            ("1" as NSString).draw(at: NSPoint(x: ruleThickness - 14, y: inset + relativeY + 8), withAttributes: attrs)
            return
        }

        let visibleGlyphs = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: container)
        let firstCharIndex = layoutManager.characterIndexForGlyph(at: visibleGlyphs.location)

        // Line number of the first visible line (count newlines before it).
        var lineNumber = 1
        if firstCharIndex > 0 {
            nsString.enumerateSubstrings(in: NSRange(location: 0, length: firstCharIndex),
                                         options: [.byLines, .substringNotRequired]) { _, _, _, _ in
                lineNumber += 1
            }
        }

        var glyphIndex = visibleGlyphs.location
        while glyphIndex < NSMaxRange(visibleGlyphs) {
            var lineRange = NSRange()
            let fragmentRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange)
            let y = fragmentRect.minY + inset + relativeY
            let label = "\(lineNumber)" as NSString
            let size = label.size(withAttributes: attrs)
            label.draw(at: NSPoint(x: ruleThickness - size.width - 6, y: y + (fragmentRect.height - size.height) / 2),
                       withAttributes: attrs)
            glyphIndex = NSMaxRange(lineRange)
            lineNumber += 1
        }
    }
}
