import SwiftUI

// MARK: - Zone Color Palette

extension Color {
    static let zone1 = Color(hex: 0x5B8BF5)  // blu     — Z1 Recupero attivo
    static let zone2 = Color(hex: 0x4CAF76)  // verde   — Z2 Resistenza
    static let zone3 = Color(hex: 0xFFD166)  // giallo  — Z3 Soglia aerobica
    static let zone4 = Color(hex: 0xF4994A)  // arancio — Z4 Soglia lattica
    static let zone5 = Color(hex: 0xE24B4B)  // rosso   — Z5 VO2max

    static let allZoneColors: [Color] = [.zone1, .zone2, .zone3, .zone4, .zone5]
}

// MARK: - Zone → Color

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

// MARK: - Grade → Color (elevation profile chart)

extension Color {
    /// Maps slope percentage to a severity color for the elevation profile.
    static func gradeColor(for grade: Double) -> Color {
        switch abs(grade) {
        case ..<2:   return Color(hex: 0x8DB48E)  // verde scuro — piano
        case 2..<4:  return Color(hex: 0xFFD166)  // giallo      — lieve
        case 4..<7:  return Color(hex: 0xF4994A)  // arancio     — moderato
        case 7..<10: return Color(hex: 0xE24B4B)  // rosso       — duro
        default:     return Color(hex: 0x9B1C1C)  // rosso scuro — >10%
        }
    }
}
