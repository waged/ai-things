import SwiftUI

/// The things-connect brand mark: a ring. By default it carries the brand dot;
/// with `text` it carries a short label (we use "AI") inside the circle.
/// Drawn with pure SwiftUI so it stays crisp at any size and adopts the theme.
struct BrandMark: View {
    var diameter: CGFloat = 22
    var color: Color = Theme.highlight
    /// Text shown inside the ring (e.g. "AI"). When nil, draws the brand dot.
    var text: String? = "AI"

    var body: some View {
        ZStack {
            Circle()
                .stroke(color, lineWidth: max(1.5, diameter * 0.11))
            if let text {
                Text(text)
                    .font(.system(size: diameter * 0.40, weight: .black, design: .rounded))
                    .foregroundStyle(color)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: diameter * 0.34, height: diameter * 0.34)
            }
        }
        .frame(width: diameter, height: diameter)
    }
}

/// App logo: the things-connect circle (with "AI" inside) + the wordmark.
struct LogoView: View {
    enum Size {
        case small   // compact
        case regular // header

        var mark: CGFloat { self == .small ? 20 : 26 }
        var word: CGFloat { self == .small ? 14 : 17 }
        var showCaption: Bool { self == .regular }
    }

    var size: Size = .regular

    var body: some View {
        HStack(spacing: 9) {
            BrandMark(diameter: size.mark, color: Theme.highlight, text: "AI")

            VStack(alignment: .leading, spacing: 0) {
                Text("Things")
                    .font(Theme.display(size.word, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                if size.showCaption {
                    Text("by things-connect.net")
                        .font(Theme.mono(9))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("AI-Things by things-connect.net")
    }
}

#Preview {
    VStack(spacing: 20) {
        LogoView(size: .regular)
        LogoView(size: .small)
        BrandMark(diameter: 72, color: Theme.highlight, text: "AI")
    }
    .padding(40)
    .background(Theme.background)
}
