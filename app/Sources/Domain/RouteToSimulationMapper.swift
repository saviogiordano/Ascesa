import Foundation

/// Transforms a raw Route into a RouteProfile ready for SIM mode.
///
/// Pipeline:
///   1. Resample track to a fixed distance step (default 15 m)
///   2. Calculate grade per segment using central differences
///   3. Apply a moving-average smoothing window (default 200 m) to suppress GPS noise
///   4. Clamp to the TACX FLUX supported range (default −10 % … +20 %)
///
/// Resistance lag (sending the grade command ~0.5 s early so the trainer
/// finishes its mechanical change at the right moment) is handled in
/// WorkoutEngine by looking up grade(at: virtualPosition + speed * 0.5).
struct RouteToSimulationMapper: Sendable {

    struct Configuration: Sendable {
        var resampleStepMeters: Double = 15
        var smoothingWindowMeters: Double = 200
        var minGradePercent: Double = -10   // TACX FLUX minimum
        var maxGradePercent: Double = 20    // TACX FLUX maximum
    }

    let config: Configuration

    init(config: Configuration = .init()) {
        self.config = config
    }

    func buildProfile(from route: Route) -> RouteProfile {
        let pts = resample(route.points)
        guard pts.count >= 2 else {
            return RouteProfile(routeID: route.id, name: route.name,
                                totalDistanceMeters: 0, totalElevationGainMeters: 0, segments: [])
        }

        let rawGrades = calculateGrades(pts)
        let smoothed = smoothGrades(rawGrades)
        let clamped = smoothed.map {
            min(config.maxGradePercent, max(config.minGradePercent, $0))
        }

        var elevGain = 0.0
        for i in 1..<pts.count {
            let rise = pts[i].altitudeMeters - pts[i - 1].altitudeMeters
            if rise > 0 { elevGain += rise }
        }

        let segments = zip(pts, clamped).map { pt, grade in
            RouteProfile.Segment(
                distanceMeters: pt.distanceMeters,
                gradePercent: grade,
                altitudeMeters: pt.altitudeMeters
            )
        }

        return RouteProfile(
            routeID: route.id,
            name: route.name,
            totalDistanceMeters: pts.last!.distanceMeters,
            totalElevationGainMeters: elevGain,
            segments: segments
        )
    }

    // MARK: - Resampling

    private func resample(_ points: [RoutePoint]) -> [RoutePoint] {
        guard let last = points.last, last.distanceMeters > 0 else { return points }
        var result: [RoutePoint] = []
        var d = 0.0
        while d < last.distanceMeters {
            result.append(interpolated(points, at: d))
            d += config.resampleStepMeters
        }
        result.append(interpolated(points, at: last.distanceMeters))
        return result
    }

    private func interpolated(_ points: [RoutePoint], at distance: Double) -> RoutePoint {
        // Binary search for the first point whose cumulative distance ≥ target
        var lo = 0, hi = points.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if points[mid].distanceMeters < distance { lo = mid + 1 } else { hi = mid }
        }
        guard lo > 0 else { return points[0] }
        let p0 = points[lo - 1], p1 = points[lo]
        let span = p1.distanceMeters - p0.distanceMeters
        let t = span > 0 ? (distance - p0.distanceMeters) / span : 0
        return RoutePoint(
            distanceMeters: distance,
            latitude: p0.latitude + t * (p1.latitude - p0.latitude),
            longitude: p0.longitude + t * (p1.longitude - p0.longitude),
            altitudeMeters: p0.altitudeMeters + t * (p1.altitudeMeters - p0.altitudeMeters)
        )
    }

    // MARK: - Grade calculation (central differences, m/s → %)

    private func calculateGrades(_ points: [RoutePoint]) -> [Double] {
        points.indices.map { i in
            let p0: RoutePoint, p1: RoutePoint
            if i == 0 {
                (p0, p1) = (points[0], points[1])
            } else if i == points.count - 1 {
                (p0, p1) = (points[points.count - 2], points[points.count - 1])
            } else {
                (p0, p1) = (points[i - 1], points[i + 1])
            }
            let run = p1.distanceMeters - p0.distanceMeters
            return run > 0 ? (p1.altitudeMeters - p0.altitudeMeters) / run * 100 : 0
        }
    }

    // MARK: - Moving-average smoothing
    // Because the track is resampled at a fixed step, the window width in indices
    // is constant: halfWindow = smoothingWindowMeters / (2 × stepMeters).

    private func smoothGrades(_ grades: [Double]) -> [Double] {
        let half = max(1, Int(config.smoothingWindowMeters / (2 * config.resampleStepMeters)))
        return grades.indices.map { i in
            let lo = max(0, i - half)
            let hi = min(grades.count - 1, i + half)
            let slice = grades[lo...hi]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }
}

// MARK: - RouteProfile lookups

extension RouteProfile {
    /// Linear interpolation of altitude at an arbitrary virtual position.
    func altitude(at virtualPositionMeters: Double) -> Double {
        guard !segments.isEmpty else { return 0 }
        if virtualPositionMeters <= segments[0].distanceMeters {
            return segments[0].altitudeMeters
        }
        let last = segments[segments.count - 1]
        if virtualPositionMeters >= last.distanceMeters {
            return last.altitudeMeters
        }
        var lo = 0, hi = segments.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if segments[mid].distanceMeters < virtualPositionMeters { lo = mid + 1 } else { hi = mid }
        }
        guard lo > 0 else { return segments[0].altitudeMeters }
        let s0 = segments[lo - 1], s1 = segments[lo]
        let span = s1.distanceMeters - s0.distanceMeters
        guard span > 0 else { return s0.altitudeMeters }
        let t = (virtualPositionMeters - s0.distanceMeters) / span
        return s0.altitudeMeters + t * (s1.altitudeMeters - s0.altitudeMeters)
    }

    /// Linear interpolation of grade at an arbitrary virtual position.
    /// WorkoutEngine calls this every tick. For lag compensation pass
    /// `virtualPositionMeters + speed_ms * 0.5` as the argument.
    func grade(at virtualPositionMeters: Double) -> Double {
        guard !segments.isEmpty else { return 0 }
        if virtualPositionMeters <= segments[0].distanceMeters {
            return segments[0].gradePercent
        }
        let last = segments[segments.count - 1]
        if virtualPositionMeters >= last.distanceMeters {
            return last.gradePercent
        }
        // Binary search for bracket
        var lo = 0, hi = segments.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if segments[mid].distanceMeters < virtualPositionMeters { lo = mid + 1 } else { hi = mid }
        }
        guard lo > 0 else { return segments[0].gradePercent }
        let s0 = segments[lo - 1], s1 = segments[lo]
        let span = s1.distanceMeters - s0.distanceMeters
        guard span > 0 else { return s0.gradePercent }
        let t = (virtualPositionMeters - s0.distanceMeters) / span
        return s0.gradePercent + t * (s1.gradePercent - s0.gradePercent)
    }
}
