import Foundation

// GPX 1.1 encoder with Garmin TrackPointExtension v1 for HR and cadence.
//
// Since this is an indoor session there are no real GPS coordinates.
// lat/lon are fixed at 0.0; the elevation comes from the virtual route profile.
// The primary use of the GPX export is carrying altitude + HR + cadence data.
//
// Schema: http://www.topografix.com/GPX/1/1
// Extension: http://www.garmin.com/xmlschemas/TrackPointExtension/v1
struct GPXExporter: Sendable {

    func export(session: WorkoutSession, records: [SessionRecord]) throws -> Data {
        guard !records.isEmpty else { throw ExportError.noRecords }

        let fmt      = iso8601Formatter()
        let name     = gpxName(session: session)
        let startStr = fmt.string(from: session.startDate)

        var xml = gpxHeader(name: name, startDate: startStr)

        for r in records {
            xml += trackpoint(r, fmt: fmt)
        }

        xml += """

            </trkseg>
          </trk>
        </gpx>
        """

        guard let data = xml.data(using: .utf8) else {
            throw ExportError.noRecords
        }
        return data
    }

    // MARK: - Private

    private func iso8601Formatter() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }

    private func gpxName(session: WorkoutSession) -> String {
        switch session.mode {
        case .erg(let w):           return "Indoor ERG \(w) W"
        case .simulation(let id):   return "Indoor SIM \(id.uuidString.prefix(8))"
        case .free:                 return "Indoor Free Ride"
        }
    }

    private func gpxHeader(name: String, startDate: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Ascesa"
             xmlns="http://www.topografix.com/GPX/1/1"
             xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1
               http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>\(xmlEsc(name))</name>
            <time>\(startDate)</time>
          </metadata>
          <trk>
            <name>\(xmlEsc(name))</name>
            <trkseg>
        """
    }

    private func trackpoint(_ r: SessionRecord, fmt: ISO8601DateFormatter) -> String {
        var tp = """

              <trkpt lat="0.0" lon="0.0">
                <ele>\(String(format: "%.1f", r.altitudeMeters))</ele>
                <time>\(fmt.string(from: r.timestamp))</time>
        """

        let hasHR  = r.heartRateBPM != nil
        let hasCad = r.cadenceRPM > 0
        if hasHR || hasCad {
            tp += """

                <extensions>
                  <gpxtpx:TrackPointExtension>
        """
            if let bpm = r.heartRateBPM {
                tp += "\n            <gpxtpx:hr>\(bpm)</gpxtpx:hr>"
            }
            if hasCad {
                tp += "\n            <gpxtpx:cad>\(r.cadenceRPM)</gpxtpx:cad>"
            }
            tp += """

                  </gpxtpx:TrackPointExtension>
                </extensions>
        """
        }

        tp += "\n          </trkpt>"
        return tp
    }

    // Escape the five XML predefined entities.
    private func xmlEsc(_ s: String) -> String {
        s.replacingOccurrences(of: "&",  with: "&amp;")
         .replacingOccurrences(of: "<",  with: "&lt;")
         .replacingOccurrences(of: ">",  with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
         .replacingOccurrences(of: "'",  with: "&apos;")
    }
}
