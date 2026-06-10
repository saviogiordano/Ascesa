import Foundation

enum Zone: Int, CaseIterable, Sendable, Comparable {
    case z1 = 1, z2, z3, z4, z5

    var label: String { "Z\(rawValue)" }

    static func < (lhs: Zone, rhs: Zone) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct PowerZones: Sendable {
    let ftp: Int

    func zone(for watts: Int) -> Zone {
        let pct = Double(watts) / Double(ftp)
        return switch pct {
        case ..<0.56:        .z1
        case 0.56..<0.76:   .z2
        case 0.76..<0.91:   .z3
        case 0.91..<1.06:   .z4
        default:            .z5
        }
    }
}

struct HeartRateZones: Sendable {
    let maxHR: Int

    func zone(for bpm: Int) -> Zone {
        let pct = Double(bpm) / Double(maxHR)
        return switch pct {
        case ..<0.60:        .z1
        case 0.60..<0.70:   .z2
        case 0.70..<0.80:   .z3
        case 0.80..<0.90:   .z4
        default:            .z5
        }
    }
}
