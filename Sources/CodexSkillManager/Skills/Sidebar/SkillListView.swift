import SwiftUI

struct SkillListView: View {
    @Environment(SkillStore.self) private var store

    let localSkills: [Skill]

    @Binding var localSelection: Skill.ID?

    private var groupedLocalSkills: [SkillStore.LocalSkillGroup] {
        store.groupedLocalSkills(from: localSkills)
    }

    var body: some View {
        List(selection: $localSelection) {
            SidebarHeaderView(skillCount: groupedLocalSkills.count)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            localSectionContent()
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await store.loadSkills() }
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
            }
        }
    }

    @ViewBuilder
    private func localSectionContent() -> some View {
        let platformSkills = store.groupedPlatformSkills(from: localSkills)
        let hasAnySkills = !platformSkills.isEmpty || !store.customPaths.isEmpty

        if !hasAnySkills {
            Text("No skills yet.")
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        } else {
            if !platformSkills.isEmpty {
                Section("Skills") {
                    localRows(for: platformSkills)
                }
            }

            // Custom path sections
            ForEach(store.customPaths) { customPath in
                let pathSkills = localSkills.filter { $0.customPath?.id == customPath.id }
                let grouped = store.groupedLocalSkills(from: pathSkills)

                Section {
                    if grouped.isEmpty {
                        Text("No skills in this folder.")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        localRows(for: grouped)
                    }
                } header: {
                    CustomPathSectionHeader(customPath: customPath)
                }
            }
        }
    }

    @ViewBuilder
    private func localRows(for skills: [SkillStore.LocalSkillGroup]) -> some View {
        ForEach(skills) { skill in
            SkillRowView(
                skill: skill.skill,
                installedPlatforms: skill.installedPlatforms
            )
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    Task { await store.deleteSkills(ids: skill.deleteIDs) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .onDelete { offsets in
            let ids = offsets
                .filter { skills.indices.contains($0) }
                .flatMap { skills[$0].deleteIDs }
            Task { await store.deleteSkills(ids: ids) }
        }
    }
}
