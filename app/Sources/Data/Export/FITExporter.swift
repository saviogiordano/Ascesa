import Foundation

// FIT Activity encoder — Garmin FIT SDK 21.141.
//
// FIT epoch: Dec 31 1989 00:00:00 UTC = Unix timestamp 631 065 600.
// All multi-byte fields are little-endian (architecture byte = 0x00).
//
// Message layout written:
//   file_id → event(start) → record×N → event(stop) → lap×M → session → activity
struct FITExporter: Sendable {

    // MARK: - Public

    func export(
        session: WorkoutSession,
        records: [SessionRecord],
        athlete: AthleteProfile
    ) throws -> Data {
        guard !records.isEmpty else { throw ExportError.noRecords }

        var b = FITBuilder()
        let s = FITSummary(records: records)
        let groups = lapGroups(records)

        // ── file_id (global 0, local 0) ───────────────────────────────────────
        b.define(local: 0, global: 0, fields: [
            FITFld(0, .fitEnum,  1),   // type
            FITFld(1, .uint16,   2),   // manufacturer
            FITFld(2, .uint16,   2),   // product
            FITFld(4, .uint32,   4),   // time_created
        ])
        b.data(local: 0, values: [.u8(4), .u16(255), .u16(0), .u32(s.startFIT)])

        // ── event: timer start (global 21, local 1) ───────────────────────────
        b.define(local: 1, global: 21, fields: [
            FITFld(253, .uint32,  4),  // timestamp
            FITFld(0,   .fitEnum, 1),  // event  (0 = timer)
            FITFld(1,   .fitEnum, 1),  // event_type (0 = start)
        ])
        b.data(local: 1, values: [.u32(s.startFIT), .u8(0), .u8(0)])

        // ── record (global 20, local 2) ───────────────────────────────────────
        // speed scale 1000 → mm/s; distance scale 100 → cm; altitude (m+500)×5.
        b.define(local: 2, global: 20, fields: [
            FITFld(253, .uint32, 4),   // timestamp
            FITFld(7,   .uint16, 2),   // power (W)
            FITFld(4,   .uint8,  1),   // cadence (rpm)
            FITFld(6,   .uint16, 2),   // speed (mm/s)
            FITFld(3,   .uint8,  1),   // heart_rate (0xFF = invalid)
            FITFld(5,   .uint32, 4),   // distance (cm)
            FITFld(2,   .uint16, 2),   // altitude ((m+500)×5)
        ])
        for r in records {
            b.data(local: 2, values: [
                .u32(fitTS(r.timestamp)),
                .u16(sat16(r.powerWatts)),
                .u8(sat8(r.cadenceRPM)),
                .u16(sat16(Int(r.speedKmh / 3.6 * 1000))),
                .u8(r.heartRateBPM.map { sat8($0) } ?? 0xFF),
                .u32(UInt32(max(0.0, r.distanceMeters * 100))),
                .u16(sat16(Int((r.altitudeMeters + 500.0) * 5))),
            ])
        }

        // ── event: timer stop ────────────────────────────────────────────────
        b.data(local: 1, values: [.u32(s.endFIT), .u8(0), .u8(4)])  // stop_all

        // ── lap (global 19, local 3) ─────────────────────────────────────────
        // lap_trigger: 0 = manual, 7 = session_end (last lap only).
        b.define(local: 3, global: 19, fields: [
            FITFld(254, .uint16,  2),  // message_index
            FITFld(253, .uint32,  4),  // timestamp (end)
            FITFld(2,   .uint32,  4),  // start_time
            FITFld(7,   .uint32,  4),  // total_elapsed_time (ms)
            FITFld(8,   .uint32,  4),  // total_timer_time (ms)
            FITFld(9,   .uint32,  4),  // total_distance (cm)
            FITFld(15,  .uint16,  2),  // avg_power (W)
            FITFld(20,  .fitEnum, 1),  // lap_trigger
            FITFld(21,  .fitEnum, 1),  // sport (2 = cycling)
        ])
        for (i, g) in groups.enumerated() where !g.isEmpty {
            let ms  = UInt32(g.last!.timestamp.timeIntervalSince(g.first!.timestamp) * 1000)
            let cm  = UInt32(max(0.0, (g.last!.distanceMeters - g.first!.distanceMeters) * 100))
            let avgW = sat16(g.map(\.powerWatts).reduce(0, +) / g.count)
            let trig: UInt8 = i == groups.count - 1 ? 7 : 0
            b.data(local: 3, values: [
                .u16(UInt16(i)),
                .u32(fitTS(g.last!.timestamp)),
                .u32(fitTS(g.first!.timestamp)),
                .u32(ms), .u32(ms), .u32(cm),
                .u16(avgW), .u8(trig), .u8(2),
            ])
        }

        // ── session (global 18, local 4) ──────────────────────────────────────
        // event=8 (session), event_type=1 (stop).
        // sport=2 (cycling), sub_sport=6 (indoor_cycling).
        b.define(local: 4, global: 18, fields: [
            FITFld(253, .uint32,  4),  // timestamp
            FITFld(0,   .fitEnum, 1),  // event
            FITFld(1,   .fitEnum, 1),  // event_type
            FITFld(2,   .uint32,  4),  // start_time
            FITFld(5,   .fitEnum, 1),  // sport
            FITFld(6,   .fitEnum, 1),  // sub_sport
            FITFld(7,   .uint32,  4),  // total_elapsed_time (ms)
            FITFld(8,   .uint32,  4),  // total_timer_time (ms)
            FITFld(9,   .uint32,  4),  // total_distance (cm)
            FITFld(15,  .uint16,  2),  // avg_power (W)
            FITFld(16,  .uint16,  2),  // max_power (W)
            FITFld(17,  .uint16,  2),  // total_ascent (m)
            FITFld(20,  .uint16,  2),  // first_lap_index
            FITFld(21,  .uint16,  2),  // num_laps
            FITFld(24,  .uint8,   1),  // avg_heart_rate
            FITFld(25,  .uint8,   1),  // max_heart_rate
            FITFld(26,  .uint8,   1),  // avg_cadence
        ])
        b.data(local: 4, values: [
            .u32(s.endFIT),
            .u8(8), .u8(1),
            .u32(s.startFIT),
            .u8(2), .u8(6),
            .u32(s.durationMs), .u32(s.durationMs),
            .u32(s.totalDistCm),
            .u16(s.avgPower), .u16(s.maxPower), .u16(s.totalAscent),
            .u16(0), .u16(UInt16(groups.count)),
            .u8(s.avgHR), .u8(s.maxHR), .u8(s.avgCadence),
        ])

        // ── activity (global 34, local 5) ─────────────────────────────────────
        // event=26 (activity), event_type=1 (stop), type=0 (manual).
        b.define(local: 5, global: 34, fields: [
            FITFld(253, .uint32,  4),  // timestamp
            FITFld(0,   .uint32,  4),  // total_timer_time (ms)
            FITFld(1,   .uint16,  2),  // num_sessions
            FITFld(2,   .fitEnum, 1),  // type
            FITFld(3,   .fitEnum, 1),  // event
            FITFld(4,   .fitEnum, 1),  // event_type
        ])
        b.data(local: 5, values: [
            .u32(s.endFIT), .u32(s.durationMs),
            .u16(1), .u8(0), .u8(26), .u8(1),
        ])

        return b.finalize()
    }

    // MARK: - Private helpers

    // FIT epoch offset from Unix epoch (Dec 31 1989 00:00:00 UTC).
    private static let fitEpochOffset: UInt64 = 631_065_600

    private func fitTS(_ date: Date) -> UInt32 {
        let unix = UInt64(max(0.0, date.timeIntervalSince1970))
        let off  = FITExporter.fitEpochOffset
        return unix > off ? UInt32(min(unix - off, UInt64(UInt32.max))) : 0
    }

    private func lapGroups(_ rs: [SessionRecord]) -> [[SessionRecord]] {
        guard !rs.isEmpty else { return [] }
        var groups: [[SessionRecord]] = []
        var cur = [rs[0]]
        for r in rs.dropFirst() {
            if r.lapIndex == cur.last!.lapIndex { cur.append(r) }
            else { groups.append(cur); cur = [r] }
        }
        groups.append(cur)
        return groups
    }

    // Clamp Int to UInt16 range.
    private func sat16(_ v: Int) -> UInt16 { UInt16(max(0, min(65535, v))) }
    // Clamp Int to UInt8 range (0–254; 0xFF reserved for "invalid").
    private func sat8(_ v: Int)  -> UInt8  { UInt8(max(0, min(254, v))) }
}

// MARK: - Session summary statistics

private struct FITSummary {
    let startFIT, endFIT, durationMs, totalDistCm: UInt32
    let avgPower, maxPower, totalAscent: UInt16
    let avgHR, maxHR, avgCadence: UInt8

    init(records rs: [SessionRecord]) {
        let offset = UInt64(631_065_600)
        func ts(_ d: Date) -> UInt32 {
            let u = UInt64(max(0.0, d.timeIntervalSince1970))
            return u > offset ? UInt32(min(u - offset, UInt64(UInt32.max))) : 0
        }
        startFIT    = ts(rs.first!.timestamp)
        endFIT      = ts(rs.last!.timestamp)
        durationMs  = UInt32(max(0.0, rs.last!.timestamp.timeIntervalSince(rs.first!.timestamp)) * 1000)
        totalDistCm = UInt32(max(0.0, rs.last!.distanceMeters * 100))

        let pw = rs.map(\.powerWatts)
        let n  = max(1, pw.count)
        avgPower = UInt16(min(65535, pw.reduce(0, +) / n))
        maxPower = UInt16(min(65535, pw.max() ?? 0))

        var asc = 0.0
        for i in 1..<rs.count {
            let delta = rs[i].altitudeMeters - rs[i - 1].altitudeMeters
            if delta > 0 { asc += delta }
        }
        totalAscent = UInt16(min(65535, Int(asc.rounded())))

        let hrs = rs.compactMap(\.heartRateBPM)
        avgHR = hrs.isEmpty ? 0xFF : UInt8(min(254, hrs.reduce(0, +) / max(1, hrs.count)))
        maxHR = hrs.isEmpty ? 0xFF : UInt8(min(254, hrs.max() ?? 0))

        let cad = rs.map(\.cadenceRPM)
        avgCadence = UInt8(min(254, cad.reduce(0, +) / max(1, cad.count)))
    }
}

// MARK: - FIT binary builder

// Field definition (3 bytes in the binary: field_def_num, size, base_type_byte).
private struct FITFld {
    let num: UInt8
    let baseType: FITBaseType
    let size: UInt8
    init(_ num: UInt8, _ bt: FITBaseType, _ sz: UInt8) {
        self.num = num; self.baseType = bt; self.size = sz
    }
}

// Base type bytes as defined in the FIT SDK. The high bit indicates a multi-byte field.
private enum FITBaseType: UInt8 {
    case fitEnum  = 0x00   // enum  — 1 byte
    case uint8    = 0x02   // uint8 — 1 byte
    case uint16   = 0x84   // uint16 — 2 bytes LE
    case uint32   = 0x86   // uint32 — 4 bytes LE
}

// Typed value used when building a data message.
private enum FITVal {
    case u8(UInt8), u16(UInt16), u32(UInt32)

    var bytes: [UInt8] {
        switch self {
        case .u8(let v):  return [v]
        case .u16(let v): return [v.fitLo, v.fitHi]
        case .u32(let v): return [v.fitB0, v.fitB1, v.fitB2, v.fitB3]
        }
    }
}

private struct FITBuilder {
    private var raw: [UInt8] = []

    /// Write a definition message. Must precede the first data message for each local type.
    mutating func define(local: UInt8, global: UInt16, fields: [FITFld]) {
        // Header: 0x40 | localType, reserved, architecture (0=LE), global mesg num (LE), field count.
        raw += [0x40 | (local & 0x0F), 0x00, 0x00, global.fitLo, global.fitHi, UInt8(fields.count)]
        for f in fields { raw += [f.num, f.size, f.baseType.rawValue] }
    }

    /// Write a data message. Values must match the preceding definition in order and type.
    mutating func data(local: UInt8, values: [FITVal]) {
        raw.append(local & 0x0F)
        values.forEach { raw += $0.bytes }
    }

    /// Assemble the complete FIT file: file header (14 bytes) + data + file CRC (2 bytes).
    func finalize() -> Data {
        // 12-byte header body (before its own CRC).
        let sz = UInt32(raw.count)
        let headerBody: [UInt8] = [
            14, 0x10,                                              // header size, protocol ver
            0x54, 0x08,                                            // profile ver 2132 (LE)
            sz.fitB0, sz.fitB1, sz.fitB2, sz.fitB3,               // data size (LE)
            0x2E, 0x46, 0x49, 0x54,                                // ".FIT"
        ]
        let hdrCRC = fitCRC16(headerBody)
        let fullHeader = headerBody + [hdrCRC.fitLo, hdrCRC.fitHi]
        let all = fullHeader + raw
        let fileCRC = fitCRC16(all)
        return Data(all + [fileCRC.fitLo, fileCRC.fitHi])
    }
}

// MARK: - FIT CRC-16 (nibble lookup table, from Garmin FIT SDK source)

private let fitCRCTable: [UInt16] = [
    0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
    0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400,
]

private func fitCRC16(_ bytes: [UInt8], seed: UInt16 = 0) -> UInt16 {
    var crc = seed
    for byte in bytes {
        var tmp = fitCRCTable[Int(crc & 0x0F)]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ^ tmp ^ fitCRCTable[Int(byte & 0x0F)]
        tmp = fitCRCTable[Int(crc & 0x0F)]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ^ tmp ^ fitCRCTable[Int((byte >> 4) & 0x0F)]
    }
    return crc
}

// MARK: - LE byte-extraction helpers

private extension UInt16 {
    var fitLo: UInt8 { UInt8(self & 0xFF) }
    var fitHi: UInt8 { UInt8((self >> 8) & 0xFF) }
}

private extension UInt32 {
    var fitB0: UInt8 { UInt8(self & 0xFF) }
    var fitB1: UInt8 { UInt8((self >> 8) & 0xFF) }
    var fitB2: UInt8 { UInt8((self >> 16) & 0xFF) }
    var fitB3: UInt8 { UInt8((self >> 24) & 0xFF) }
}
