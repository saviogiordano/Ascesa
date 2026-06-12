import SwiftUI

// MARK: - Brand Colors

extension Color {
    static let indigoBackground = Color(hex: 0x1E2A52)
    static let indigoMid        = Color(hex: 0x2E4288)
    static let amber            = Color(hex: 0xFFB84D)
}

// MARK: - Spacing

enum Spacing {
    static let xs:  CGFloat =  4
    static let sm:  CGFloat =  8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 24
    static let xxl: CGFloat = 32
}

// MARK: - Typography

enum Typography {
    /// Hero metric (power, HR). Apply .monospacedDigit() on the Text view.
    static func metricHero(size: CGFloat = 72) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static let metricUnit:  Font = .system(size: 18, weight: .semibold)
    static let metricLabel: Font = .system(size: 11, weight: .semibold)
    static let body:        Font = .body
    static let secondary:   Font = .system(size: 12, weight: .medium)
    static let caption:     Font = .system(size: 10, weight: .regular)
}

// MARK: - Color(hex:) initializer

extension Color {
    init(hex: UInt32) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255
        )
    }
}
