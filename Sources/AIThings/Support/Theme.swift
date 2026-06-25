import SwiftUI

/// Central palette and fonts, aligned to the things-connect brand:
/// deep navy backgrounds, white text, a steel-blue accent.
///
/// Two blues by design:
///  - `accent`  is a deep steel-blue used as a *fill* (white text reads cleanly on it).
///  - `highlight` is a lighter blue used for *text / icons on dark backgrounds*
///    (a deep blue on navy would be unreadable — this fixes the old white-on-cyan mix).
enum Theme {
    // Backgrounds (navy)
    static let background      = Color(red: 0.043, green: 0.086, blue: 0.130)
    static let surface         = Color(red: 0.067, green: 0.118, blue: 0.169)
    static let surfaceElevated = Color(red: 0.090, green: 0.153, blue: 0.220)
    static let border          = Color.white.opacity(0.085)

    /// Subtle diagonal gradient echoing the brand's hero image.
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.063, green: 0.122, blue: 0.180),
            Color(red: 0.031, green: 0.063, blue: 0.098)
        ],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )

    // Text
    static let textPrimary   = Color(red: 0.914, green: 0.941, blue: 0.969)
    static let textSecondary = Color(red: 0.522, green: 0.592, blue: 0.663)

    // Accents
    static let accent    = Color(red: 0.145, green: 0.388, blue: 0.627) // deep steel-blue FILL
    static let highlight = Color(red: 0.357, green: 0.651, blue: 0.910) // lighter blue TEXT/icons
    static let user      = Color(red: 0.482, green: 0.769, blue: 0.498) // soft green prompt
    static let success   = Color(red: 0.450, green: 0.780, blue: 0.520)
    static let warning   = Color(red: 0.920, green: 0.740, blue: 0.420)
    static let danger    = Color(red: 0.890, green: 0.460, blue: 0.460)

    // Fonts
    static func mono(_ size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Rounded display font for the brand wordmark (echoes the techno logo).
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static let cornerRadius: CGFloat = 8
}

extension View {
    /// A subtle card surface used throughout the UI.
    func terminalCard() -> some View {
        self
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}
