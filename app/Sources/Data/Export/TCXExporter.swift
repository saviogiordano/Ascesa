import Foundation

// Training Center XML encoder (Garmin TCX v2 + ActivityExtension v2 for power).
//
// Schema: http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2
// Extension: http://www.garmin.com/xmlschemas/ActivityExtension/v2
//
// Records are grouped by lapIndex. Each lap becomes a <Lap> element with its own
// <Track> containing one <Trackpoint> per SessionRecord.
struct TCXExporter: Sendable {

    func export(session: WorkoutSession, records: [SessionRecord]) throws -> Data {
        guard !records.isEmpty else { throw ExportError.noRecords }

        let fmt = iso8601Formatter()
        let groups = lapGroups(records)
        let startStr = fmt.string(from: session.startDate)

        var xml = tcxHeader(startDate: startStr)

        for (i, g) in groups.enumerated() where !g.isEmpty {
            xml += lapElement(index: i, records: g, isLast: i == groups.count - 1, fmt: fmt)
        }

        xml += """
              </Activity>
            </Activities>
          </TrainingCenterDatabase>
          """

        guard let data = xml.data(using: .utf8) else {
            throw ExportError.noRecords // encoding never fails for this content
        }
        return data
    }

    // MARK: - Private

    private func iso8601Formatter() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
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

    private func tcxHeader(startDate: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <TrainingCenterDatabase
            xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2"
            xmlns:AX2="http://www.garmin.com/xmlschemas/ActivityExtension/v2"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xsi:schemaLocation="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2
              http://www.garmin.com/xmlschemas/TrainingCenterDatabasev2.xsd">
          <Activities>
            <Activity Sport="Biking">
              <Id>\(startDate)</Id>
        """
    }

    private func lapElement(
        index: Int,
        records g: [SessionRecord],
        isLast: Bool,
        fmt: ISO8601DateFormatter
    ) -> String {
        let startStr   = fmt.string(from: g.first!.timestamp)
        let duration   = g.last!.timestamp.timeIntervalSince(g.first!.timestamp)
        let distMeters = max(0.0, g.last!.distanceMeters - g.first!.distanceMeters)
        let maxSpeed   = g.map(\.speedKmh).max().map { $0 / 3.6 } ?? 0.0

        let powers = g.map(\.powerWatts)
        let avgW   = powers.reduce(0, +) / max(1, powers.count)
        let maxW   = powers.max() ?? 0

        let cads   = g.map(\.cadenceRPM)
        let maxCad = cads.max() ?? 0

        let hrs    = g.compactMap(\.heartRateBPM)
        let avgHR  = hrs.isEmpty ? nil : hrs.reduce(0, +) / hrs.count
        let maxHR  = hrs.max()

        let trigger = isLast ? "None" : "Manual"

        // Compute session calories from mechanical work (kJ → kcal, ~4.184 kJ/kcal).
        let totalKJ   = Double(powers.reduce(0, +)) * (duration / Double(max(1, powers.count))) / 1000.0
        let kcal      = Int((totalKJ / 4.184).rounded())

        var lap = """
              <Lap StartTime="\(startStr)">
                <TotalTimeSeconds>\(String(format: "%.1f", duration))</TotalTimeSeconds>
                <DistanceMeters>\(String(format: "%.1f", distMeters))</DistanceMeters>
                <MaximumSpeed>\(String(format: "%.3f", maxSpeed))</MaximumSpeed>
                <Calories>\(kcal)</Calories>
        """

        if let avgHR {
            lap += """

                <AverageHeartRateBpm><Value>\(avgHR)</Value></AverageHeartRateBpm>
        """
        }
        if let maxHR {
            lap += """

                <MaximumHeartRateBpm><Value>\(maxHR)</Value></MaximumHeartRateBpm>
        """
        }

        lap += """

                <Intensity>Active</Intensity>
                <TriggerMethod>\(trigger)</TriggerMethod>
                <Track>
        """

        for r in g {
            lap += trackpoint(r, fmt: fmt)
        }

        lap += """

                </Track>
                <Extensions>
                  <AX2:LX>
                    <AX2:MaxBikeCadence>\(maxCad)</AX2:MaxBikeCadence>
                    <AX2:AvgWatts>\(avgW)</AX2:AvgWatts>
                    <AX2:MaxWatts>\(maxW)</AX2:MaxWatts>
                  </AX2:LX>
                </Extensions>
              </Lap>
        """
        return lap + "\n"
    }

    private func trackpoint(_ r: SessionRecord, fmt: ISO8601DateFormatter) -> String {
        var tp = """

                  <Trackpoint>
                    <Time>\(fmt.string(from: r.timestamp))</Time>
                    <AltitudeMeters>\(String(format: "%.1f", r.altitudeMeters))</AltitudeMeters>
                    <DistanceMeters>\(String(format: "%.1f", r.distanceMeters))</DistanceMeters>
        """

        if let bpm = r.heartRateBPM {
            tp += """

                    <HeartRateBpm><Value>\(bpm)</Value></HeartRateBpm>
        """
        }

        tp += """

                    <Cadence>\(r.cadenceRPM)</Cadence>
                    <Extensions>
                      <AX2:TPX>
                        <AX2:Speed>\(String(format: "%.3f", r.speedKmh / 3.6))</AX2:Speed>
                        <AX2:Watts>\(r.powerWatts)</AX2:Watts>
                      </AX2:TPX>
                    </Extensions>
                  </Trackpoint>
        """
        return tp
    }
}
