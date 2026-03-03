import MarkdownUI
import SwiftUI

struct SkillMarkdownView: View {
    let skill: Skill
    let markdown: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Markdown(markdown)
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
            .padding()
        }
        .navigationTitle(skill.displayName)
        .navigationSubtitle(skill.folderPath)
    }
}
