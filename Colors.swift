import SwiftUI

// MARK: - Color System
extension Color {
    static let appBackground = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let cardBackground = Color(red: 0.15, green: 0.15, blue: 0.16)
    static let primaryBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    static let successGreen = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let warningYellow = Color(red: 1.0, green: 0.8, blue: 0.0)
    static let errorRed = Color(red: 1.0, green: 0.27, blue: 0.23)
    
    // Text colors
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(white: 0.6)
    
    // Border colors
    static let borderColor = Color(white: 0.3, opacity: 0.5)
    static let borderHighlight = Color.primaryBlue.opacity(0.6)
}