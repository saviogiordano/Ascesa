import GRDB
import Foundation

/// GRDB record mapped to the `session_records` table.
/// Codable conformance drives the FetchableRecord / PersistableRecord synthesis automatically.
struct SessionRecordRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "session_records"

    var id: String
    var sessionID: String
    var timestamp: Double
    var powerW: Int
    var cadenceRPM: Int
    var speedKmh: Double
    var distanceM: Double
    var hrBPM: Int?
    var gradePct: Double
    var virtualPositionM: Double
    var altitudeM: Double
    var lapIndex: Int

    enum CodingKeys: String, CodingKey {
        case id
        case sessionID        = "session_id"
        case timestamp
        case powerW           = "power_w"
        case cadenceRPM       = "cadence_rpm"
        case speedKmh         = "speed_kmh"
        case distanceM        = "distance_m"
        case hrBPM            = "hr_bpm"
        case gradePct         = "grade_pct"
        case virtualPositionM = "virtual_position_m"
        case altitudeM        = "altitude_m"
        case lapIndex         = "lap_index"
    }

    init(_ record: SessionRecord) {
        id              = record.id.uuidString
        sessionID       = record.sessionID.uuidString
        timestamp       = record.timestamp.timeIntervalSince1970
        powerW          = record.powerWatts
        cadenceRPM      = record.cadenceRPM
        speedKmh        = record.speedKmh
        distanceM       = record.distanceMeters
        hrBPM           = record.heartRateBPM
        gradePct        = record.gradePercent
        virtualPositionM = record.virtualPositionMeters
        altitudeM       = record.altitudeMeters
        lapIndex        = record.lapIndex
    }

    func toSessionRecord() -> SessionRecord {
        SessionRecord(
            id:                   UUID(uuidString: id)        ?? UUID(),
            sessionID:            UUID(uuidString: sessionID) ?? UUID(),
            timestamp:            Date(timeIntervalSince1970: timestamp),
            powerWatts:           powerW,
            cadenceRPM:           cadenceRPM,
            speedKmh:             speedKmh,
            distanceMeters:       distanceM,
            heartRateBPM:         hrBPM,
            gradePercent:         gradePct,
            virtualPositionMeters: virtualPositionM,
            altitudeMeters:       altitudeM,
            lapIndex:             lapIndex
        )
    }
}
