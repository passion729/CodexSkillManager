import AppKit
import SwiftUI

struct SkillSplitView: View {
    @Environment(SkillStore.self) private var store

    @State private var searchText = ""
    @State private var showingImport = false
    @State private var showingAddPath = false

    private var filteredSkills: [Skill] {
        guard !searchText.isEmpty else { return store.skills }
        return store.skills.filter { skill in
            skill.displayName.localizedCaseInsensitiveContains(searchText)
                || skill.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            SkillListView(
                localSkills: filteredSkills,
                localSelection: localSelectionBinding
            )
            .environment(store)
        } detail: {
            SkillDetailView()
                .environment(store)
        }
        .task {
            await store.loadSkills()
        }
        .onChange(of: store.selectedSkillID) { _, _ in
            Task { await store.loadSelectedSkill() }
        }
        .toolbar(id: "main-toolbar") {
            toolbarContent()
        }
        .sheet(isPresented: $showingImport) {
            ImportSkillView()
                .environment(store)
        }
        .sheet(isPresented: $showingAddPath) {
            AddCustomPathView()
                .environment(store)
        }
        .searchable(
            text: $searchText,
            placement: .sidebar,
            prompt: "Filter skills"
        )
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some CustomizableToolbarContent {
        ToolbarItem(id: "open") {
            openFolderItem
        }

        if #available(macOS 26.0, *) {
            ToolbarSpacer(.fixed)
        }

        ToolbarItem(id: "add") {
            Menu {
                Button("Import Skill...") {
                    showingImport = true
                }
                Button("Add Custom Path...") {
                    showingAddPath = true
                }
            } label: {
                Label("Add", systemImage: "plus")
            }
            .labelStyle(.iconOnly)
        }
    }

    @ViewBuilder
    private var openFolderItem: some View {
        if shouldShowOpenFolderMenu {
            Menu {
                ForEach(SkillPlatform.allCases) { platform in
                    if installedPlatformsForSelected.contains(platform) {
                        Button("Open \(platform.rawValue) Folder") {
                            openSelectedSkillFolder(platform: platform)
                        }
                    }
                }
            } label: {
                Label("Open Skill Folder", systemImage: "folder")
            }
            .labelStyle(.iconOnly)
        } else {
            Button {
                openSelectedSkillFolder(platform: nil)
            } label: {
                Label("Open Skill Folder", systemImage: "folder")
            }
            .labelStyle(.iconOnly)
        }
    }

    private var shouldShowOpenFolderMenu: Bool {
        installedPlatformsForSelected.count > 1
    }

    private var installedPlatformsForSelected: Set<SkillPlatform> {
        guard let slug = store.selectedSkill?.name else { return [] }
        return store.installedPlatforms(for: slug)
    }

    private var localSelectionBinding: Binding<Skill.ID?> {
        Binding(
            get: { store.selectedSkillID },
            set: { store.selectedSkillID = $0 }
        )
    }

    private func openSelectedSkillFolder(platform: SkillPlatform?) {
        let fallbackURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/skills")
        let selected = store.selectedSkill
        let url: URL
        if let platform, let slug = selected?.name {
            if let selected, selected.platform == platform {
                url = selected.folderURL
            } else if let match = store.skills.first(where: {
                $0.name == slug && $0.platform == platform && $0.customPath == selected?.customPath
            }) {
                url = match.folderURL
            } else if let match = store.skills.first(where: { $0.name == slug && $0.platform == platform }) {
                url = match.folderURL
            } else {
                url = platform.rootURL.appendingPathComponent(slug)
            }
        } else {
            url = selected?.folderURL ?? fallbackURL
        }
        NSWorkspace.shared.open(url)
    }
}
