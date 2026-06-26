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
            if runActive { progressStrip }
            if expanded { stepGrid }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surface)
    }

    // MARK: - Live progress (visible while a pipeline runs)

    private var runActive: Bool { !model.stepStatus.isEmpty }

    private var progressStrip: some View {
        let steps = model.settings.automationSteps.filter(\.enabled)
        let total = steps.count
        let done = steps.filter { model.stepStatus[$0.kind] == .done }.count
        let running = steps.first { model.stepStatus[$0.kind] == .running }
        let failed = steps.first { model.stepStatus[$0.kind] == .failed }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                if let failed {
                    Image(systemName: "xmark.octagon.fill").foregroundStyle(Theme.danger)
                    Text("Stopped at \(failed.kind.title) — fix it, then run again")
                        .font(Theme.mono(11, weight: .semibold)).foregroundStyle(Theme.danger)
                } else {
                    if running != nil { ProgressView().controlSize(.mini) }
                    else { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success) }
                    Text(running != nil
                         ? "Running \(running!.kind.title) — step \(done + 1) of \(total)"
                         : "Automation complete — \(done)/\(total) steps")
                        .font(Theme.mono(11, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(steps) { step in
                        stepChip(step.kind)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func stepChip(_ kind: AutomationStep.Kind) -> some View {
        let state = model.stepStatus[kind]
        HStack(spacing: 5) {
            switch state {
            case .running: ProgressView().controlSize(.mini)
            case .done:    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
            case .failed:  Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
            default:        Image(systemName: kind.symbol).font(.system(size: 9))
            }
            Text(kind.title).font(Theme.mono(9.5, weight: state == .running ? .bold : .regular))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .foregroundStyle(chipColor(state))
        .background(chipColor(state).opacity(0.16))
        .clipShape(Capsule())
    }

    private func chipColor(_ state: AppModel.StepState?) -> Color {
        switch state {
        case .running: return Theme.warning
        case .done:    return Theme.success
        case .failed:  return Theme.danger
        default:        return Theme.textSecondary
        }
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
                VStack(alignment: .leading, spacing: 6) {
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

                    // Per-step config, inline right under its own row.
                    if step.kind == .review && step.enabled { reviewChecklist }
                    if step.kind == .bumpVersion && step.enabled { versionBumpField }
                    if step.kind == .mergeAndPush && step.enabled { mergeTargetField }
                }
                .opacity(model.settings.automationEnabled ? 1 : 0.5)
            }

            Text("Steps run in order as agent turns after each task you send.")
                .font(Theme.mono(9))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 2)
        }
    }

    private var reviewChecklist: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Checklist — the Review gate checks these:")
                .font(Theme.mono(9.5)).foregroundStyle(Theme.textSecondary)
            TextEditor(text: $model.settings.reviewRules)
                .font(Theme.mono(10.5))
                .scrollContentBackground(.hidden)
                .frame(height: 96)
                .padding(6)
                .background(Theme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
        }
        .padding(.leading, 22) // indent under the Review row
        .padding(.bottom, 4)
    }

    private var versionBumpField: some View {
        HStack(spacing: 8) {
            Text("Increment:").font(Theme.mono(9.5)).foregroundStyle(Theme.textSecondary)
            Picker("", selection: $model.settings.versionBump) {
                ForEach(VersionBump.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 240)
        }
        .padding(.leading, 22)
        .padding(.bottom, 4)
    }

    private var mergeTargetField: some View {
        HStack(spacing: 6) {
            Text("Target branch:").font(Theme.mono(9.5)).foregroundStyle(Theme.textSecondary)
            TextField("auto (main / master)", text: $model.settings.releaseBranch)
                .textFieldStyle(.roundedBorder)
                .font(Theme.mono(11))
                .frame(maxWidth: 220)
        }
        .padding(.leading, 22)
        .padding(.bottom, 4)
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
