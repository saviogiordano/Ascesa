import Foundation

struct AthleteProfile: Codable, Sendable {
    var weightKg: Double
    var ftpWatts: Int
    var maxHeartRate: Int

    var powerZones: PowerZones  { PowerZones(ftp: ftpWatts) }
    var heartRateZones: HeartRateZones { HeartRateZones(maxHR: maxHeartRate) }

    static let placeholder = AthleteProfile(weightKg: 75, ftpWatts: 250, maxHeartRate: 185)
}
