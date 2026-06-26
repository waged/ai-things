import SwiftUI

/// A panel that shows a changed file's diff (or contents, if untracked) with
/// standard +/- coloring. Opened from the sidebar's changed-files list.
struct DiffViewerView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let file: GitFileChange

    @State private var diff = ""
    @State private var loading = true
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Theme.border)
            content
        }
        .frame(width: 760, height: 580)
        .background(Theme.background)
        .task {
            diff = await model.loadDiff(for: file)
            loading = false
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass").foregroundStyle(Theme.highlight)
            VStack(alignment: .leading, spacing: 1) {
                Text(file.name).font(Theme.mono(13, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                Text(file.path).font(Theme.mono(9)).foregroundStyle(Theme.textSecondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(diff, forType: .string)
                copied = true
            } label: {
                Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .font(Theme.mono(10))
            }
            .buttonStyle(.bordered).controlSize(.small)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent).controlSize(.small).tint(Theme.accent)
        }
        .padding(14)
        .background(Theme.surface)
    }

    @ViewBuilder
    private var content: some View {
        if loading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(diff.split(separator: "\n", omittingEmptySubsequences: false).enumerated()), id: \.offset) { _, line in
                        Text(String(line).isEmpty ? " " : String(line))
                            .font(Theme.mono(12))
                            .foregroundStyle(color(for: String(line)))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                    }
                }
                .padding(.vertical, 10)
            }
            .background(Theme.background)
        }
    }

    private func color(for line: String) -> Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") { return Theme.success }
        if line.hasPrefix("-") && !line.hasPrefix("---") { return Theme.danger }
        if line.hasPrefix("@@") { return Theme.highlight }
        if line.hasPrefix("diff ") || line.hasPrefix("index ") { return Theme.textSecondary }
        return Theme.textPrimary
    }
}
