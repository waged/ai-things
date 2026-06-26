import SwiftUI

/// Toolbar menu that opens a pre-filled GitHub issue (bug or feature) in the
/// browser, so users can report directly to the repo with one click.
/// (Mirrors the BLE-Explorer feedback menu.)
struct FeedbackMenu: View {
    @Environment(\.openURL) private var openURL

    /// The project's GitHub repository.
    private let repo = "https://github.com/waged/ai-things"

    var body: some View {
        Menu {
            Button { openIssue(.bug) } label: {
                Label("Report a Bug", systemImage: "ladybug")
            }
            Button { openIssue(.feature) } label: {
                Label("Request a Feature", systemImage: "lightbulb")
            }
            Divider()
            Button {
                if let url = URL(string: "\(repo)/issues") { openURL(url) }
            } label: {
                Label("View Issues on GitHub", systemImage: "list.bullet.rectangle")
            }
        } label: {
            Image(systemName: "exclamationmark.bubble")
        }
        .help("Report a bug or request a feature")
    }

    private enum Kind { case bug, feature }

    private func openIssue(_ kind: Kind) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let os = ProcessInfo.processInfo.operatingSystemVersionString

        let title: String, body: String, label: String
        switch kind {
        case .bug:
            label = "bug"
            title = "[Bug] "
            body = """
            ### Describe the bug


            ### Steps to reproduce
            1.
            2.

            ### Expected behavior


            ### Environment
            - AI-Things: \(version) (\(build))
            - macOS: \(os)
            """
        case .feature:
            label = "enhancement"
            title = "[Feature] "
            body = """
            ### What would you like to add?


            ### Why would it be useful?


            _AI-Things \(version) (\(build))_
            """
        }

        guard var comps = URLComponents(string: "\(repo)/issues/new") else { return }
        comps.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "labels", value: label),
            URLQueryItem(name: "body", value: body),
        ]
        if let url = comps.url { openURL(url) }
    }
}
