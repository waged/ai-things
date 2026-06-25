import SwiftUI

/// The things-connect brand mark: a ring with a centered dot (the motif from
/// the logo, where it replaces the "O"). Drawn with pure SwiftUI so it stays
/// crisp at any size and adopts the theme color.
struct BrandMark: View {
    var diameter: CGFloat = 18
    var color: Color = Theme.textPrimary

    var body: some View {
        ZStack {
            Circle()
                .stroke(color, lineWidth: diameter * 0.16)
            Circle()
                .fill(color)
                .frame(width: diameter * 0.34, height: diameter * 0.34)
        }
        .frame(width: diameter, height: diameter)
    }
}

/// App logo: brand mark + "AI-Things" wordmark, with the things-connect
/// attribution. Fits the macOS header and sidebar.
struct LogoView: View {
    enum Size {
        case small   // compact
        case regular // header

        var mark: CGFloat { self == .small ? 16 : 20 }
        var word: CGFloat { self == .small ? 14 : 17 }
        var showCaption: Bool { self == .regular }
    }

    var size: Size = .regular

    var body: some View {
        HStack(spacing: 9) {
            BrandMark(diameter: size.mark, color: Theme.highlight)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text("AI")
                        .font(Theme.display(size.word - 2, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Theme.accent)
                        )
                    Text("Things")
                        .font(Theme.display(size.word, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                }
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
        BrandMark(diameter: 64, color: Theme.highlight)
    }
    .padding(40)
    .background(Theme.background)
}
