import Foundation
import CoreGPX

/// Parses .gpx files into RoutePoint arrays.
/// Handles both track segments (<trkseg>) and fallback to waypoints (<wpt>).
/// Altitude is taken from <ele> when present; defaults to 0 if absent.
struct GPXParser {

    enum ParserError: Error, LocalizedError {
        case invalidFile
        case emptyTrack

        var errorDescription: String? {
            switch self {
            case .invalidFile: "Il file GPX non è valido o non può essere letto."
            case .emptyTrack: "Il file GPX non contiene punti traccia."
            }
        }
    }

    func parse(contentsOf url: URL) throws -> [RoutePoint] {
        guard let root = CoreGPX.GPXParser(withURL: url)?.parsedData() else {
            throw ParserError.invalidFile
        }
        return try buildPoints(from: root)
    }

    func parse(data: Data) throws -> [RoutePoint] {
        guard let root = CoreGPX.GPXParser(withData: data).parsedData() else {
            throw ParserError.invalidFile
        }
        return try buildPoints(from: root)
    }

    // MARK: - Private

    private func buildPoints(from root: GPXRoot) throws -> [RoutePoint] {
        var raw: [(lat: Double, lon: Double, alt: Double)] = []

        for track in root.tracks {
            for segment in track.segments {
                for tp in segment.trackpoints {
                    guard let lat = tp.latitude, let lon = tp.longitude else { continue }
                    raw.append((lat, lon, tp.elevation ?? 0))
                }
            }
        }

        // Fallback: use waypoints if no track points were found
        if raw.isEmpty {
            for wp in root.waypoints {
                guard let lat = wp.latitude, let lon = wp.longitude else { continue }
                raw.append((lat, lon, wp.elevation ?? 0))
            }
        }

        guard !raw.isEmpty else { throw ParserError.emptyTrack }
        return accumulate(raw)
    }

    private func accumulate(_ raw: [(lat: Double, lon: Double, alt: Double)]) -> [RoutePoint] {
        var result: [RoutePoint] = []
        var cumDist = 0.0
        for (i, p) in raw.enumerated() {
            if i > 0 {
                cumDist += haversine(raw[i - 1].lat, raw[i - 1].lon, p.lat, p.lon)
            }
            result.append(RoutePoint(
                distanceMeters: cumDist,
                latitude: p.lat,
                longitude: p.lon,
                altitudeMeters: p.alt
            ))
        }
        return result
    }

    private func haversine(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let R = 6_371_000.0
        let φ1 = lat1 * .pi / 180, φ2 = lat2 * .pi / 180
        let Δφ = (lat2 - lat1) * .pi / 180
        let Δλ = (lon2 - lon1) * .pi / 180
        let a = sin(Δφ / 2) * sin(Δφ / 2) + cos(φ1) * cos(φ2) * sin(Δλ / 2) * sin(Δλ / 2)
        return R * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}
