import SwiftUI

enum ClientViewerTheme {
    static let pagePadding = 20.0
    static let sectionSpacing = 18.0
    static let cardSpacing = 14.0
    static let panelSpacing = 12.0
    static let cardPadding = 18.0
    static let cardCornerRadius = 24.0
    static let compactCornerRadius = 16.0
    static let buttonHeight = 56.0

    static let pageBackground = Color.white
    static let cardBackground = Color(red: 0.965, green: 0.976, blue: 0.992)
    static let cardBorder = Color.black.opacity(0.06)
    static let primaryText = Color.black
    static let secondaryText = Color(red: 0.42, green: 0.46, blue: 0.54)
    static let accent = Color(red: 0.231, green: 0.51, blue: 0.965)
    static let accentSoft = Color(red: 0.917, green: 0.953, blue: 1.0)
    static let success = Color(red: 0.094, green: 0.611, blue: 0.329)
    static let warning = Color(red: 0.925, green: 0.486, blue: 0.149)
    static let failure = Color(red: 0.851, green: 0.188, blue: 0.188)

    static let connectGradient = LinearGradient(
        colors: [
            Color(red: 0.122, green: 0.458, blue: 0.996),
            Color(red: 0.2, green: 0.62, blue: 1.0)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}
