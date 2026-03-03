import SwiftUI

struct SidebarHeaderView: View {
    let skillCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Installed Skills")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            Text("\(skillCount) skills")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .textCase(nil)
    }
}
