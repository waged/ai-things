import SwiftUI

/// Root layout: header on top, sidebar + terminal split below, composer at the bottom.
struct MainAppView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showSettings = false
    @State private var showBranchCreator = false

    var body: some View {
        VStack(spacing: 0) {
            HeaderBarView(showSettings: $showSettings)

            Divider().overlay(Theme.border)

            NavigationSplitView {
                SidebarView(showBranchCreator: $showBranchCreator)
                    .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
            } detail: {
                VStack(spacing: 0) {
                    GitToolbarView(showBranchCreator: $showBranchCreator)
                    Divider().overlay(Theme.border)
                    TerminalChatView()
                    Divider().overlay(Theme.border)
                    InputComposerView()
                }
            }
            .navigationSplitViewStyle(.balanced)
        }
        .background(Theme.backgroundGradient)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(model)
        }
        .sheet(isPresented: $showBranchCreator) {
            BranchCreatorView { kind, name in
                model.createBranch(kind: kind, name: name)
            }
        }
    }
}

#Preview {
    MainAppView()
        .environmentObject(AppModel())
        .frame(width: 1000, height: 680)
}
