import CodeEditorView
import Foundation
import Observation

@MainActor
@Observable final class SkillStore {
    enum ListState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    enum DetailState: Equatable {
        case idle
        case loading
        case loaded
        case missing
        case failed(String)
    }

    struct LocalSkillGroup: Identifiable {
        let id: Skill.ID
        let skill: Skill
        let installedPlatforms: Set<SkillPlatform>
        let deleteIDs: [Skill.ID]
    }

    var skills: [Skill] = []
    var listState: ListState = .idle
    var detailState: DetailState = .idle
    var referenceState: DetailState = .idle
    var selectedSkillID: Skill.ID?
    var selectedMarkdown: String = ""
    var selectedReferenceID: SkillReference.ID?
    var selectedReferenceMarkdown: String = ""
    var isEditing: Bool = false
    var editDraft: String = ""
    var editPosition: CodeEditor.Position = CodeEditor.Position()
    var selectedRawMarkdown: String = ""

    private let fileWorker = SkillFileWorker()
    private let importWorker = SkillImportWorker()
    private let customPathStore: CustomPathStore

    init(customPathStore: CustomPathStore = CustomPathStore()) {
        self.customPathStore = customPathStore
    }

    var customPaths: [CustomSkillPath] {
        customPathStore.customPaths
    }

    func addCustomPath(_ url: URL) throws {
        try customPathStore.addPath(url)
    }

    func removeCustomPath(_ path: CustomSkillPath) {
        customPathStore.removePath(path)
    }

    var selectedSkill: Skill? {
        skills.first { $0.id == selectedSkillID }
    }

    var selectedReference: SkillReference? {
        guard let selectedSkill, let selectedReferenceID else { return nil }
        return selectedSkill.references.first { $0.id == selectedReferenceID }
    }

    func loadSkills() async {
        listState = .loading
        detailState = .idle
        referenceState = .idle
        do {
            let platforms = SkillPlatform.allCases.flatMap { platform in
                zip(platform.relativePaths, platform.rootURLs).map { relativePath, rootURL in
                    (platform, rootURL, platform.storageKey(forRelativePath: relativePath))
                }
            }
            var skills: [Skill] = []

            // Scan platform paths
            for (platform, rootURL, storageKey) in platforms {
                let scanned = try await fileWorker.scanSkills(at: rootURL, storageKey: storageKey)
                skills.append(contentsOf: scanned.map { scannedSkill in
                    Skill(
                        id: scannedSkill.id,
                        name: scannedSkill.name,
                        displayName: scannedSkill.displayName,
                        description: scannedSkill.description,
                        platform: platform,
                        customPath: nil,
                        folderURL: scannedSkill.folderURL,
                        skillMarkdownURL: scannedSkill.skillMarkdownURL,
                        references: scannedSkill.references,
                        stats: scannedSkill.stats
                    )
                })
            }

            // Scan custom paths - auto-discover platform subpaths
            let fileManager = FileManager.default
            for customPath in customPathStore.customPaths {
                for platform in SkillPlatform.allCases {
                    for (relativePath, platformURL) in zip(platform.relativePaths, platform.skillsURLs(in: customPath.url)) {
                        guard fileManager.fileExists(atPath: platformURL.path) else { continue }

                        let storageKey = "\(customPath.storageKey)-\(platform.storageKey(forRelativePath: relativePath))"
                        let scanned = try await fileWorker.scanSkills(at: platformURL, storageKey: storageKey)
                        skills.append(contentsOf: scanned.map { scannedSkill in
                            Skill(
                                id: scannedSkill.id,
                                name: scannedSkill.name,
                                displayName: scannedSkill.displayName,
                                description: scannedSkill.description,
                                platform: platform,
                                customPath: customPath,
                                folderURL: scannedSkill.folderURL,
                                skillMarkdownURL: scannedSkill.skillMarkdownURL,
                                references: scannedSkill.references,
                                stats: scannedSkill.stats
                            )
                        })
                    }
                }
            }

            self.skills = skills.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }

            listState = .loaded
            if let selectedSkillID,
               self.skills.contains(where: { $0.id == selectedSkillID }) == false {
                self.selectedSkillID = self.skills.first?.id
            } else if selectedSkillID == nil {
                selectedSkillID = self.skills.first?.id
            }

            normalizeSelectionToPreferredPlatform()
            await loadSelectedSkill()
        } catch {
            listState = .failed(error.localizedDescription)
        }
    }

    func loadSelectedSkill() async {
        guard !isEditing else { return }
        guard let selectedSkill else {
            detailState = .idle
            selectedMarkdown = ""
            selectedRawMarkdown = ""
            editDraft = ""
            isEditing = false
            referenceState = .idle
            selectedReferenceID = nil
            selectedReferenceMarkdown = ""
            return
        }

        let skillURL = selectedSkill.skillMarkdownURL

        detailState = .loading
        referenceState = .idle
        selectedReferenceID = nil
        selectedReferenceMarkdown = ""

        do {
            let raw = try await fileWorker.loadMarkdown(at: skillURL)
            selectedRawMarkdown = raw
            selectedMarkdown = stripFrontmatter(from: raw)
            detailState = .loaded
        } catch {
            detailState = .failed(error.localizedDescription)
            selectedMarkdown = ""
        }
    }

    func selectReference(_ reference: SkillReference) async {
        selectedReferenceID = reference.id
        await loadSelectedReference()
    }

    func loadSelectedReference() async {
        guard let selectedReference else {
            referenceState = .idle
            selectedReferenceMarkdown = ""
            return
        }

        referenceState = .loading

        do {
            let raw = try await fileWorker.loadMarkdown(at: selectedReference.url)
            selectedReferenceMarkdown = stripFrontmatter(from: raw)
            referenceState = .loaded
        } catch {
            referenceState = .failed(error.localizedDescription)
            selectedReferenceMarkdown = ""
        }
    }

    func beginEditing() {
        editDraft = selectedRawMarkdown
        isEditing = true
    }

    func cancelEditing() {
        isEditing = false
        editDraft = ""
    }

    func saveSkill() async {
        guard let selectedSkill else { return }
        let content = editDraft
        do {
            try await fileWorker.saveMarkdown(at: selectedSkill.skillMarkdownURL, content: content)
            selectedRawMarkdown = content
            selectedMarkdown = stripFrontmatter(from: content)
            isEditing = false
            editDraft = ""
        } catch {
            // Keep isEditing = true so user can retry or cancel
        }
    }

    func deleteSkills(ids: [Skill.ID]) async {
        let fileManager = FileManager.default
        for id in ids {
            guard let skill = skills.first(where: { $0.id == id }) else { continue }
            try? fileManager.removeItem(at: skill.folderURL)
        }
        await loadSkills()
    }

    func groupedLocalSkills(from filteredSkills: [Skill]) -> [LocalSkillGroup] {
        let grouped = Dictionary(grouping: filteredSkills, by: { $0.name })
        let preferredPlatformOrder: [SkillPlatform] = [.codex, .claude, .opencode, .copilot]

        return grouped.compactMap { _, filteredSkills in
            guard let preferredSelection = preferredPlatformOrder
                .compactMap({ platform in filteredSkills.first(where: { $0.platform == platform }) })
                .first ?? filteredSkills.first else {
                return nil
            }

            let preferredContent = preferredPlatformOrder
                .compactMap({ platform in filteredSkills.first(where: { $0.platform == platform }) })
                .first ?? preferredSelection

            // Limit platforms to the filtered scope (e.g. custom path sections).
            let installedPlatforms = Set(filteredSkills.compactMap(\.platform))

            return LocalSkillGroup(
                id: preferredSelection.id,
                skill: preferredContent,
                installedPlatforms: installedPlatforms,
                deleteIDs: filteredSkills.map(\.id)
            )
        }
        .sorted { lhs, rhs in
            lhs.skill.displayName.localizedCaseInsensitiveCompare(rhs.skill.displayName) == .orderedAscending
        }
    }

    func groupedPlatformSkills(from skills: [Skill]) -> [LocalSkillGroup] {
        groupedLocalSkills(from: skills.filter { $0.customPath == nil })
    }

    func skillsForCustomPath(_ path: CustomSkillPath) -> [Skill] {
        skills.filter { $0.customPath?.id == path.id }
    }

    func platformSkills() -> [Skill] {
        skills.filter { $0.platform != nil }
    }

    func installedPlatforms(for slug: String) -> Set<SkillPlatform> {
        Set(skills.filter { $0.name == slug }.compactMap(\.platform))
    }

    private func normalizeSelectionToPreferredPlatform() {
        guard let selectedSkillID,
              let selected = skills.first(where: { $0.id == selectedSkillID }) else {
            return
        }

        let slug = selected.name
        let candidates = skills.filter { $0.name == slug }
        guard candidates.count > 1 else { return }

        let preferredOrder: [SkillPlatform] = [.codex, .claude, .opencode, .copilot]
        let preferred = preferredOrder
            .compactMap { platform in candidates.first(where: { $0.platform == platform }) }
            .first ?? candidates.first
        if let preferred, preferred.id != selectedSkillID {
            self.selectedSkillID = preferred.id
        }
    }
}
