import SwiftUI

struct AppColors {
    // Quiet charcoal / warm paper palette — closer to Linear/Stripe than Material blue-gray.
    static let primary = Color(hex: 0x171717)
    static let onPrimary = Color(hex: 0xFFFFFF)
    static let secondary = Color(hex: 0x8A6A2F)
    static let onSecondary = Color(hex: 0xFFFFFF)
    static let background = Color(hex: 0xF7F7F5)
    static let surface = Color(hex: 0xF7F7F5)
    static let onSurface = Color(hex: 0x171717)
    static let onSurfaceVariant = Color(hex: 0x6B6B66)
    static let surfaceContainerLow = Color(hex: 0xF0F0EC)
    static let surfaceContainer = Color(hex: 0xEBEBE6)
    static let surfaceContainerHigh = Color(hex: 0xE4E4DE)
    static let surfaceContainerHighest = Color(hex: 0xDDDDD6)
    static let surfaceContainerLowest = Color(hex: 0xFFFFFF)
    static let hairline = Color.black.opacity(0.06)
    static let accentSoft = Color(hex: 0xF3E7D0)
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}
