import Foundation
import Observation

@MainActor
@Observable final class AppSettings {

    // MARK: - Preview font

    var previewFontName: String {
        didSet { UserDefaults.standard.set(previewFontName, forKey: Keys.previewFontName) }
    }

    var previewFontSize: Double {
        didSet { UserDefaults.standard.set(previewFontSize, forKey: Keys.previewFontSize) }
    }

    var previewLineSpacing: Double {
        didSet { UserDefaults.standard.set(previewLineSpacing, forKey: Keys.previewLineSpacing) }
    }

    // MARK: - Editor font

    var editorFontName: String {
        didSet { UserDefaults.standard.set(editorFontName, forKey: Keys.editorFontName) }
    }

    var editorFontSize: Double {
        didSet { UserDefaults.standard.set(editorFontSize, forKey: Keys.editorFontSize) }
    }

    var editorLineSpacing: Double {
        didSet { UserDefaults.standard.set(editorLineSpacing, forKey: Keys.editorLineSpacing) }
    }

    // MARK: - Init

    init() {
        previewFontName = UserDefaults.standard.string(forKey: Keys.previewFontName)
            ?? Self.defaultPreviewFontName
        previewFontSize = (UserDefaults.standard.object(forKey: Keys.previewFontSize) as? Double)
            ?? Self.defaultPreviewFontSize
        previewLineSpacing = (UserDefaults.standard.object(forKey: Keys.previewLineSpacing) as? Double)
            ?? Self.defaultPreviewLineSpacing

        editorFontName = UserDefaults.standard.string(forKey: Keys.editorFontName)
            ?? Self.defaultEditorFontName
        editorFontSize = (UserDefaults.standard.object(forKey: Keys.editorFontSize) as? Double)
            ?? Self.defaultEditorFontSize
        editorLineSpacing = (UserDefaults.standard.object(forKey: Keys.editorLineSpacing) as? Double)
            ?? Self.defaultEditorLineSpacing
    }

    // MARK: - Defaults

    static let defaultPreviewFontName = "Georgia"
    static let defaultPreviewFontSize: Double = 14.0
    static let defaultPreviewLineSpacing: Double = 0.3   // em units

    static let defaultEditorFontName = "SFMono-Medium"
    static let defaultEditorFontSize: Double = 13.0
    static let defaultEditorLineSpacing: Double = 4.0   // points

    // MARK: - Private

    private enum Keys {
        static let previewFontName    = "appSettings.previewFontName"
        static let previewFontSize    = "appSettings.previewFontSize"
        static let previewLineSpacing = "appSettings.previewLineSpacing"
        static let editorFontName    = "appSettings.editorFontName"
        static let editorFontSize    = "appSettings.editorFontSize"
        static let editorLineSpacing = "appSettings.editorLineSpacing"
    }
}
