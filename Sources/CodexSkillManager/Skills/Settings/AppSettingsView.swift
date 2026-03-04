import AppKit
import SwiftUI

struct AppSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var s = settings
        Form {
            Section("Preview Font") {
                FontPickerRow(fontName: $s.previewFontName, fontSize: $s.previewFontSize)
                FontSizeStepper(fontSize: $s.previewFontSize)
                LineSpacingStepper(label: "Line Spacing", value: $s.previewLineSpacing, range: 0.0...1.0, step: 0.05)
                FontPreviewRow(fontName: settings.previewFontName, fontSize: settings.previewFontSize)
            }

            Section("Editor Font") {
                FontPickerRow(fontName: $s.editorFontName, fontSize: $s.editorFontSize)
                FontSizeStepper(fontSize: $s.editorFontSize)
                LineSpacingStepper(label: "Line Spacing", value: $s.editorLineSpacing, range: 0.0...20.0, step: 1.0)
                FontPreviewRow(fontName: settings.editorFontName, fontSize: settings.editorFontSize)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .padding(.vertical, 8)
    }
}

// MARK: - Shared sub-views

/// Font name row — shows current font and opens NSFontPanel on click.
/// Each row owns its own FontReceiverView and sets it as the NSFontManager
/// target only when the user clicks, so two rows never conflict.
private struct FontPickerRow: View {
    @Binding var fontName: String
    @Binding var fontSize: Double

    var body: some View {
        HStack {
            Text("Font")
            Spacer()
            Button {
                // no-op: the actual open happens inside FontChangeReceiver via its coordinator
            } label: {
                Text(displayName)
                    .font(.custom(fontName, size: 13))
            }
            .buttonStyle(.borderless)
            .foregroundColor(.accentColor)
            // Overlay an invisible hit-testable area so the button tap goes through
            // FontChangeReceiver, which can activate its own NSView as target first.
            .overlay(
                FontChangeReceiver(fontName: fontName, fontSize: fontSize) { name, size in
                    fontName = name
                    fontSize = size
                }
                .allowsHitTesting(true)   // intercepts the tap
            )
        }
    }

    private var displayName: String {
        NSFont(name: fontName, size: CGFloat(fontSize))?.displayName ?? fontName
    }
}

/// Size stepper row.
private struct FontSizeStepper: View {
    @Binding var fontSize: Double

    var body: some View {
        Stepper(value: $fontSize, in: 9...36, step: 1) {
            HStack {
                Text("Size")
                Spacer()
                Text("\(Int(fontSize)) pt")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

/// Line spacing stepper row.
private struct LineSpacingStepper: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        Stepper(value: $value, in: range, step: step) {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: "%.2f", value))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

/// Sample text rendered with the chosen font.
private struct FontPreviewRow: View {
    let fontName: String
    let fontSize: Double

    var body: some View {
        HStack {
            Text("Preview")
                .foregroundStyle(.secondary)
                .font(.caption)
            Spacer()
            Text("The quick brown fox jumps over the lazy dog")
                .font(.custom(fontName, size: fontSize))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - NSFontPanel bridge

/// NSViewRepresentable that:
/// 1. Receives `changeFont:` for its own binding (never statically holds the global target).
/// 2. On mouse-down, registers itself as NSFontManager.target BEFORE opening the panel,
///    so only this instance handles the upcoming changeFont: callback.
private struct FontChangeReceiver: NSViewRepresentable {
    let fontName: String
    let fontSize: Double
    let onChange: (String, Double) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> FontReceiverView {
        let view = FontReceiverView()
        view.onChange = onChange
        view.currentFontName = fontName
        view.currentFontSize = fontSize
        context.coordinator.view = view
        return view
    }

    func updateNSView(_ view: FontReceiverView, context: Context) {
        view.currentFontName = fontName
        view.currentFontSize = fontSize
        view.onChange = onChange
    }

    final class Coordinator {
        weak var view: FontReceiverView?
    }
}

final class FontReceiverView: NSView {
    var currentFontName: String = AppSettings.defaultEditorFontName
    var currentFontSize: Double = AppSettings.defaultEditorFontSize
    var onChange: ((String, Double) -> Void)?

    // Accept clicks so the overlay intercepts taps.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        // Claim the target BEFORE showing the panel so changeFont: routes here.
        NSFontManager.shared.target = self
        let manager = NSFontManager.shared
        if let font = NSFont(name: currentFontName, size: CGFloat(currentFontSize)) {
            manager.setSelectedFont(font, isMultiple: false)
        }
        NSFontPanel.shared.orderFront(nil)
    }

    @objc func changeFont(_ sender: NSFontManager?) {
        guard let manager = sender else { return }
        let base = NSFont(name: currentFontName, size: CGFloat(currentFontSize))
            ?? NSFont.systemFont(ofSize: CGFloat(currentFontSize))
        let font = manager.convert(base)
        onChange?(font.fontName, Double(font.pointSize))
    }

    nonisolated override func responds(to aSelector: Selector!) -> Bool {
        if aSelector == #selector(changeFont(_:)) { return true }
        return super.responds(to: aSelector)
    }
}
