import SwiftUI

/// Shown while Claude is thinking (before the first token arrives). Turns the
/// wait into a tiny German lesson and links to free learning resources.
struct LoadingGermanView: View {
    @State private var index = 0
    @State private var pulse = false

    // Advance every 6s; each step continues the persisted cursor (no repeats).
    private let ticker = Timer.publish(every: 6, on: .main, in: .common).autoconnect()

    var body: some View {
        let phrase = GermanCoach.phrases[index]

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                dots
                Text("Claude is working — Lernpause 🇩🇪")
                    .font(Theme.mono(11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }

            Text(phrase.de)
                .font(Theme.display(16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(phrase.en)
                .font(Theme.mono(12))
                .foregroundStyle(Theme.highlight)

            Button {
                GermanCoach.openResources()
            } label: {
                Label("Free German resources (DW & more)", systemImage: "graduationcap")
                    .font(Theme.mono(10.5))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, 2)
        }
        .animation(.easeInOut(duration: 0.35), value: index)
        .padding(14)
        .frame(maxWidth: 460, alignment: .leading)
        .terminalCard()
        .onAppear {
            index = GermanCoach.nextIndex()
            pulse = true
        }
        .onReceive(ticker) { _ in
            withAnimation { index = GermanCoach.nextIndex() }
        }
    }

    /// Three gently pulsing dots.
    private var dots: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Theme.highlight)
                    .frame(width: 5, height: 5)
                    .opacity(pulse ? 0.3 : 1)
                    .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2), value: pulse)
            }
        }
        .onAppear { pulse = true }
    }
}
