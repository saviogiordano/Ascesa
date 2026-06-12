import Foundation

/// Replaces raw GPS altitudes with values from OpenRouteService Elevation API.
/// Raw GPS altitude can have ±20 m of noise; ORS uses SRTM/Copernicus DEM for accuracy.
///
/// Usage: call enrich(points:) before RouteToSimulationMapper to get clean elevation data.
/// If apiKey is empty the service is a no-op and returns the original points unchanged.
actor ElevationService {

    private let apiKey: String
    private let session: URLSession

    // ORS allows up to 2000 coordinates per request; stay well below to avoid timeouts.
    private let batchSize = 500

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func enrich(points: [RoutePoint]) async throws -> [RoutePoint] {
        guard !apiKey.isEmpty else { return points }
        var result: [RoutePoint] = []
        result.reserveCapacity(points.count)
        var offset = 0
        while offset < points.count {
            let end = min(offset + batchSize, points.count)
            let batch = Array(points[offset..<end])
            let elevations = try await fetchElevations(for: batch)
            for (i, pt) in batch.enumerated() {
                result.append(RoutePoint(
                    distanceMeters: pt.distanceMeters,
                    latitude: pt.latitude,
                    longitude: pt.longitude,
                    altitudeMeters: elevations[i]
                ))
            }
            offset += batchSize
        }
        return result
    }

    // MARK: - Private

    private func fetchElevations(for points: [RoutePoint]) async throws -> [Double] {
        let request = try buildRequest(for: points)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ElevationError.serverError
        }
        return try parseResponse(data, expectedCount: points.count)
    }

    private func buildRequest(for points: [RoutePoint]) throws -> URLRequest {
        // GeoJSON uses [longitude, latitude] coordinate order
        let body = ORSElevationRequest(
            geometry: .init(coordinates: points.map { [$0.longitude, $0.latitude] })
        )
        var request = URLRequest(url: URL(string: "https://api.openrouteservice.org/elevation/line")!)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func parseResponse(_ data: Data, expectedCount: Int) throws -> [Double] {
        let response = try JSONDecoder().decode(ORSElevationResponse.self, from: data)
        let elevations = response.geometry.coordinates.compactMap { $0.count >= 3 ? $0[2] : nil }
        guard elevations.count == expectedCount else {
            throw ElevationError.countMismatch(expected: expectedCount, got: elevations.count)
        }
        return elevations
    }

    enum ElevationError: Error, LocalizedError {
        case serverError
        case invalidResponse
        case countMismatch(expected: Int, got: Int)

        var errorDescription: String? {
            switch self {
            case .serverError: "ORS Elevation API ha restituito un errore."
            case .invalidResponse: "Risposta ORS non valida."
            case .countMismatch(let e, let g): "Attesi \(e) punti quota, ricevuti \(g)."
            }
        }
    }
}

// MARK: - Codable models for ORS API

private struct ORSElevationRequest: Encodable {
    struct Geometry: Encodable {
        let type = "LineString"
        let coordinates: [[Double]]
    }
    let format_in = "geojson"
    let format_out = "geojson"
    let dataset = "srtm"
    let geometry: Geometry
}

private struct ORSElevationResponse: Decodable {
    struct Geometry: Decodable {
        let coordinates: [[Double]]
    }
    let geometry: Geometry
}
