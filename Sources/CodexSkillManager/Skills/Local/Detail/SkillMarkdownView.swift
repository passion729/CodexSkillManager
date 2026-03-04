import CodeEditorView
import LanguageSupport
import MarkdownUI
import SwiftUI

struct SkillMarkdownView: View {
    @Environment(SkillStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    let skill: Skill
    let markdown: String

    var body: some View {
        Group {
            if store.isEditing {
                editorContent
            } else {
                previewContent
            }
        }
        .navigationTitle(skill.displayName)
        .navigationSubtitle(skill.folderPath)
        .toolbar { toolbarItems }
    }

    // MARK: - Preview

    private var previewTheme: MarkdownUI.Theme {
        let spacing = settings.previewLineSpacing
        return .basic
            .paragraph { config in
                config.label
                    .fixedSize(horizontal: false, vertical: true)
                    .relativeLineSpacing(.em(spacing))
                    .markdownMargin(top: .zero, bottom: .em(1))
            }
    }

    @ViewBuilder
    private var previewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Markdown(markdown)
                    .markdownTextStyle {
                        FontFamily(.custom(settings.previewFontName))
                        FontSize(settings.previewFontSize)
                    }
                    .markdownTheme(previewTheme)
                    .textSelection(.enabled)

                if !skill.references.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("References")
                            .font(.title2.bold())
                        ReferenceListView(references: skill.references)
                    }
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Editor

    @ViewBuilder
    private var editorContent: some View {
        @Bindable var s = store
        ZStack {
            CodeEditor(
                text: $s.editDraft,
                position: $s.editPosition,
                messages: .constant(Set()),
                language: .markdownLanguage()
            )
            .environment(\.codeEditorTheme, editorTheme)

            EditorLineSpacingApplicator(lineSpacing: settings.editorLineSpacing)
                .allowsHitTesting(false)
        }
    }

    private var editorTheme: CodeEditorView.Theme {
        let name = settings.editorFontName
        let size = CGFloat(settings.editorFontSize)
        if colorScheme == .dark {
            // Xcode Dark theme
            return CodeEditorView.Theme(
                colourScheme: .dark,
                fontName: name, fontSize: size,
                textColour: NSColor(red: 0.78, green: 0.82, blue: 0.86, alpha: 1),       // plain text
                commentColour: NSColor(red: 0.42, green: 0.48, blue: 0.53, alpha: 1),    // comments
                stringColour: NSColor(red: 0.91, green: 0.44, blue: 0.40, alpha: 1),     // strings
                characterColour: NSColor(red: 0.91, green: 0.44, blue: 0.40, alpha: 1),  // characters
                numberColour: NSColor(red: 0.82, green: 0.73, blue: 0.46, alpha: 1),     // numbers
                identifierColour: NSColor(red: 0.78, green: 0.82, blue: 0.86, alpha: 1), // identifiers
                operatorColour: NSColor(red: 0.78, green: 0.82, blue: 0.86, alpha: 1),   // operators
                keywordColour: NSColor(red: 0.98, green: 0.44, blue: 0.63, alpha: 1),    // keywords (pink)
                symbolColour: NSColor(red: 0.61, green: 0.76, blue: 0.93, alpha: 1),     // preprocessor
                typeColour: NSColor(red: 0.42, green: 0.82, blue: 0.91, alpha: 1),       // type names (cyan)
                fieldColour: NSColor(red: 0.52, green: 0.79, blue: 0.62, alpha: 1),      // instance vars (green)
                caseColour: NSColor(red: 0.82, green: 0.66, blue: 1.00, alpha: 1),       // enum cases
                backgroundColour: NSColor(red: 0.15, green: 0.16, blue: 0.18, alpha: 1), // #262A2F
                currentLineColour: NSColor(red: 0.19, green: 0.20, blue: 0.24, alpha: 1),
                selectionColour: NSColor(red: 0.25, green: 0.37, blue: 0.56, alpha: 1),
                cursorColour: NSColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1),
                invisiblesColour: NSColor(red: 0.33, green: 0.37, blue: 0.42, alpha: 1)
            )
        } else {
            // Xcode Light (Default) theme
            return CodeEditorView.Theme(
                colourScheme: .light,
                fontName: name, fontSize: size,
                textColour: NSColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1),       // plain text
                commentColour: NSColor(red: 0.39, green: 0.47, blue: 0.27, alpha: 1),    // comments (green)
                stringColour: NSColor(red: 0.77, green: 0.10, blue: 0.09, alpha: 1),     // strings (red)
                characterColour: NSColor(red: 0.77, green: 0.10, blue: 0.09, alpha: 1),  // characters
                numberColour: NSColor(red: 0.11, green: 0.00, blue: 0.81, alpha: 1),     // numbers (blue)
                identifierColour: NSColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1), // identifiers
                operatorColour: NSColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1),   // operators
                keywordColour: NSColor(red: 0.64, green: 0.07, blue: 0.56, alpha: 1),    // keywords (purple)
                symbolColour: NSColor(red: 0.39, green: 0.22, blue: 0.59, alpha: 1),     // preprocessor
                typeColour: NSColor(red: 0.11, green: 0.38, blue: 0.53, alpha: 1),       // type names (teal)
                fieldColour: NSColor(red: 0.11, green: 0.38, blue: 0.53, alpha: 1),      // instance vars
                caseColour: NSColor(red: 0.39, green: 0.22, blue: 0.59, alpha: 1),       // enum cases
                backgroundColour: NSColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1),
                currentLineColour: NSColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1),
                selectionColour: NSColor(red: 0.70, green: 0.84, blue: 1.00, alpha: 1),
                cursorColour: NSColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1),
                invisiblesColour: NSColor(red: 0.84, green: 0.84, blue: 0.84, alpha: 1)
            )
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        if store.isEditing {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { store.cancelEditing() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Save") { Task { await store.saveSkill() } }
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
            }
        } else {
            ToolbarItem(placement: .primaryAction) {
                Button { store.beginEditing() } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .keyboardShortcut("e", modifiers: .command)
            }
        }
    }
}

// MARK: - Editor line spacing bridge

/// Invisible zero-size view placed in the same ZStack as CodeEditor.
/// Both share the same NSHostingView, so superview.firstDescendant reliably
/// finds the CodeView (NSTextView subclass) and applies line spacing.
private struct EditorLineSpacingApplicator: NSViewRepresentable {
    let lineSpacing: Double

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        let spacing = lineSpacing
        DispatchQueue.main.async {
            // Walk up until we find a common ancestor that contains an NSTextView,
            // stopping at the window's contentView to avoid escaping the window.
            var ancestor: NSView? = nsView.superview
            while let node = ancestor {
                if let textView = node.firstDescendant(ofType: NSTextView.self) {
                    let style = NSMutableParagraphStyle()
                    style.lineSpacing = spacing
                    textView.defaultParagraphStyle = style
                    textView.typingAttributes[.paragraphStyle] = style
                    let fullRange = NSRange(location: 0, length: textView.textStorage?.length ?? 0)
                    textView.textStorage?.addAttribute(.paragraphStyle, value: style, range: fullRange)
                    return
                }
                // Stop at the hosting window's content view.
                if node === node.window?.contentView { break }
                ancestor = node.superview
            }
        }
    }
}

private extension NSView {
    func firstDescendant<T: NSView>(ofType type: T.Type) -> T? {
        for sub in subviews {
            if let match = sub as? T { return match }
            if let match = sub.firstDescendant(ofType: type) { return match }
        }
        return nil
    }
}
