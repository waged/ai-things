import SwiftUI

/// App settings: AI provider, safety, and default composer behavior.
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Settings")
                    .font(Theme.mono(16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            }
            .padding(18)

            Divider().overlay(Theme.border)

            Form {
                Section("AI Provider") {
                    Picker("Provider", selection: $model.settings.providerKind) {
                        ForEach(AIProviderKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .onChange(of: model.settings.providerKind) { _, _ in model.reloadProvider() }

                    if model.settings.providerKind == .claudeCode {
                        TextField("Model (blank = CLI default, or opus / sonnet / haiku)",
                                  text: $model.settings.modelName)
                            .onChange(of: model.settings.modelName) { _, _ in model.reloadProvider() }
                        Toggle("Skip permission prompts (run edits directly)",
                               isOn: $model.settings.skipPermissions)
                            .onChange(of: model.settings.skipPermissions) { _, _ in model.reloadProvider() }
                        Label("Runs your local `claude` CLI inside the open project. Authentication uses your existing Claude Code login — no API key is stored here.",
                              systemImage: "checkmark.seal")
                            .font(Theme.mono(10))
                            .foregroundStyle(Theme.textSecondary)
                    } else if !model.settings.providerKind.isImplemented {
                        Label("\(model.settings.providerKind.label) isn't wired up yet. Use “Claude Code (CLI)” for real results, or “Mock” offline.",
                              systemImage: "info.circle")
                            .font(Theme.mono(10))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Section("Safety") {
                    Toggle("Confirm destructive git actions", isOn: $model.settings.confirmDestructiveActions)
                    Label("Discard / reset / force-push / delete always warn when enabled.",
                          systemImage: "exclamationmark.shield")
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.textSecondary)
                }

                Section("Default Message Mode") {
                    Toggle("Ask questions first", isOn: $model.settings.defaultImprovement.askQuestionsFirst)
                    Toggle("Direct mode", isOn: $model.settings.defaultImprovement.directMode)
                    Toggle("Precise (ultra-concise answers)", isOn: $model.settings.defaultImprovement.precise)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 500, height: 560)
        .background(Theme.background)
    }
}
