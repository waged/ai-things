import SwiftUI

/// Small form for creating a new branch. Picks a kind, takes a short name,
/// and shows a live preview of the formatted branch name.
struct BranchCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kind: BranchKind = .feature
    @State private var name: String = ""

    /// Called with the chosen kind + raw name; the model formats the final name.
    let onCreate: (BranchKind, String) -> Void

    private var preview: String {
        AppModel.formatBranchName(kind: kind, name: name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Branch")
                .font(Theme.mono(16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Type").font(Theme.mono(11)).foregroundStyle(Theme.textSecondary)
                Picker("", selection: $kind) {
                    ForEach(BranchKind.allCases) { k in
                        Label(k.label, systemImage: k.symbol).tag(k)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Name").font(Theme.mono(11)).foregroundStyle(Theme.textSecondary)
                TextField("e.g. login screen", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(Theme.mono(13))
                    .onSubmit(create)
            }

            HStack(spacing: 6) {
                Image(systemName: "arrow.branch").foregroundStyle(Theme.highlight)
                Text(preview.isEmpty ? "feature/…" : preview)
                    .font(Theme.mono(12, weight: .semibold))
                    .foregroundStyle(preview.isEmpty ? Theme.textSecondary : Theme.success)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .terminalCard()

            Text("Runs: git checkout -b \(preview.isEmpty ? "<branch>" : preview)")
                .font(Theme.mono(10))
                .foregroundStyle(Theme.textSecondary)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create Branch") { create() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(preview.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
        .background(Theme.background)
    }

    private func create() {
        guard !preview.isEmpty else { return }
        onCreate(kind, name)
        dismiss()
    }
}
