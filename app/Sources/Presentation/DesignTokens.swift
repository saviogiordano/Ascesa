import SwiftUI

// MARK: - Brand Colors

extension Color {
    static let indigoBackground = Color(hex: 0x1E2A52)
    static let indigoMid        = Color(hex: 0x2E4288)
    static let amber            = Color(hex: 0xFFB84D)
}

// MARK: - Zone Colors (Presentation mapping of Domain.Zone)

extension Color {
    static let zone1 = Color(hex: 0x5B8BF5) // blu    — Z1 Recupero attivo
    static let zone2 = Color(hex: 0x4CAF76) // verde  — Z2 Resistenza
    static let zone3 = Color(hex: 0xFFD166) // giallo — Z3 Soglia aerobica
    static let zone4 = Color(hex: 0xF4994A) // arancio — Z4 Soglia lattica
    static let zone5 = Color(hex: 0xE24B4B) // rosso  — Z5 VO2max
}

extension Zone {
    var color: Color {
        switch self {
        case .z1: .zone1
        case .z2: .zone2
        case .z3: .zone3
        case .z4: .zone4
        case .z5: .zone5
        }
    }
}

// MARK: - Elevation Gradient Colors (profile chart)

extension Color {
    /// Returns the grade-zone color for a given slope percentage.
    static func gradeColor(for grade: Double) -> Color {
        switch abs(grade) {
        case ..<2:   return Color(hex: 0x8DB48E)  // verde scuro — piano
        case 2..<4:  return Color(hex: 0xFFD166)  // giallo
        case 4..<7:  return Color(hex: 0xF4994A)  // arancio
        case 7..<10: return Color(hex: 0xE24B4B)  // rosso
        default:     return Color(hex: 0x9B1C1C)  // rosso scuro — > 10%
        }
    }
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
