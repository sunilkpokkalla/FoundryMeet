import SwiftUI

struct AppColors {
    static let primary = Color(hex: 0x000000)
    static let onPrimary = Color(hex: 0xFFFFFF)
    static let secondary = Color(hex: 0x745b20)
    static let onSecondary = Color(hex: 0xFFFFFF)
    static let background = Color(hex: 0xf8f9ff)
    static let surface = Color(hex: 0xf8f9ff)
    static let onSurface = Color(hex: 0x0d1c2e)
    static let onSurfaceVariant = Color(hex: 0x4c4640)
    static let surfaceContainerLow = Color(hex: 0xeff4ff)
    static let surfaceContainer = Color(hex: 0xe6eeff)
    static let surfaceContainerHigh = Color(hex: 0xdce9ff)
    static let surfaceContainerHighest = Color(hex: 0xd5e3fc)
    static let surfaceContainerLowest = Color(hex: 0xffffff)
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
