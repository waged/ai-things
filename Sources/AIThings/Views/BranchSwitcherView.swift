import SwiftUI

/// Popover to search and switch local branches.
struct BranchSwitcherView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [GitBranch] {
        let locals = model.localBranches
        guard !query.isEmpty else { return locals }
        return locals.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Switch Branch")
                .font(Theme.mono(11, weight: .bold))
                .foregroundStyle(Theme.textSecondary)

            TextField("Search branches…", text: $query)
                .textFieldStyle(.roundedBorder)
                .font(Theme.mono(12))

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if filtered.isEmpty {
                        Text("No matching branches")
                            .font(Theme.mono(10))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.vertical, 6)
                    }
                    ForEach(filtered) { branch in
                        Button {
                            model.switchBranch(branch.name)
                            dismiss()
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: branch.isCurrent ? "checkmark.circle.fill" : "arrow.branch")
                                    .font(.system(size: 10))
                                Text(branch.name).font(Theme.mono(11)).lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 4).padding(.horizontal, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(branch.isCurrent ? Theme.accent.opacity(0.18) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(branch.isCurrent ? Theme.highlight : Theme.textPrimary)
                        .disabled(branch.isCurrent)
                    }
                }
            }
            .frame(maxHeight: 240)
        }
        .padding(12)
        .frame(width: 300)
        .background(Theme.surface)
    }
}
