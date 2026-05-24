import SwiftUI

// MARK: - Color System
//
// All colors are semantic and adaptive: they follow the user's Light/Dark
// appearance and the system accent color automatically. Nothing is hardcoded
// to a single appearance, so the app feels native on macOS 26.
extension Color {
    /// Window background — adapts to the active appearance.
    static let appBackground = Color(nsColor: .windowBackgroundColor)
    /// Raised surface for cards/rows. Pair with `.regularMaterial` for glass.
    static let cardBackground = Color(nsColor: .controlBackgroundColor)

    /// Primary tint follows the user's chosen system accent color.
    static let primaryBlue = Color.accentColor

    /// Status colors use system semantics so they adapt across appearances.
    static let successGreen = Color.green
    static let warningYellow = Color.orange
    static let errorRed = Color.red

    // Text colors
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)

    // Border colors
    static let borderColor = Color(nsColor: .separatorColor)
    static let borderHighlight = Color.accentColor.opacity(0.6)
}
