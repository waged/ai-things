import SwiftUI

/// A visible, toggleable automation pipeline. When enabled, the checked steps
/// run as follow-up agent turns after each task (review → translations →
/// docs → version → commit). Shows live status while running.
struct AutomationBarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if expanded {
                stepGrid
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surface)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Toggle(isOn: $model.settings.automationEnabled) {
                Label("Automation", systemImage: "wand.and.rays")
            }
            .toggleStyle(VividToggleStyle())

            if model.settings.automationEnabled {
                Text(enabledSummary)
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
            } label: {
                Label(expanded ? "Hide steps" : "Steps",
                      systemImage: expanded ? "chevron.up" : "slider.horizontal.3")
                    .font(Theme.mono(10.5))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary)
        }
    }

    private var enabledSummary: String {
        let on = model.settings.automationSteps.filter(\.enabled)
        return on.isEmpty ? "no steps selected" : on.map { $0.kind.title }.joined(separator: " → ")
    }

    private var stepGrid: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach($model.settings.automationSteps) { $step in
                HStack(spacing: 8) {
                    statusDot(step.kind)
                    Toggle(isOn: $step.enabled) {
                        Label(step.kind.title, systemImage: step.kind.symbol)
                    }
                    .toggleStyle(VividToggleStyle())
                    .disabled(!model.settings.automationEnabled)

                    Text(step.kind.detail)
                        .font(Theme.mono(9.5))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .opacity(model.settings.automationEnabled ? 1 : 0.5)
            }
            if mergeEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.merge").foregroundStyle(Theme.highlight)
                    Text("Merge target:").font(Theme.mono(10)).foregroundStyle(Theme.textSecondary)
                    TextField("auto (main / master)", text: $model.settings.releaseBranch)
                        .textFieldStyle(.roundedBorder)
                        .font(Theme.mono(11))
                        .frame(maxWidth: 220)
                }
                .padding(.top, 2)
            }

            Text("Steps run in order as agent turns after each task you send.")
                .font(Theme.mono(9))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 2)
        }
    }

    private var mergeEnabled: Bool {
        model.settings.automationSteps.first(where: { $0.kind == .mergeAndPush })?.enabled ?? false
    }

    @ViewBuilder
    private func statusDot(_ kind: AutomationStep.Kind) -> some View {
        let state = model.stepStatus[kind]
        Circle()
            .fill(color(for: state))
            .frame(width: 7, height: 7)
            .opacity(state == nil ? 0.25 : 1)
    }

    private func color(for state: AppModel.StepState?) -> Color {
        switch state {
        case .running: return Theme.warning
        case .done:    return Theme.success
        default:        return Theme.textSecondary
        }
    }
}
