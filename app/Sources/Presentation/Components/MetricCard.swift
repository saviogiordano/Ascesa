import SwiftUI

/// A boxed metric tile: large zone-coloured number, unit, label, and a 5-segment zone bar.
struct MetricCard: View {
    let value: String
    let unit: String
    let label: String
    /// Active training zone; nil renders the zone bar at uniform low opacity.
    let zone: Zone?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(label)
                .font(Typography.metricLabel)
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(.secondary)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(Typography.metricHero(size: 48))
                    .monospacedDigit()
                    .foregroundStyle(zone?.color ?? .primary)
                Text(unit)
                    .font(Typography.metricUnit)
                    .foregroundStyle(.secondary)
            }

            ZoneBar(activeZone: zone)
        }
        .padding(Spacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Zone bar

private struct ZoneBar: View {
    let activeZone: Zone?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Zone.allCases, id: \.self) { zone in
                let isActive = zone == activeZone
                RoundedRectangle(cornerRadius: 3)
                    .fill(zone.color)
                    .frame(height: 6)
                    .opacity(isActive ? 1 : 0.22)
                    .shadow(color: isActive ? zone.color : .clear, radius: 4)
                    .animation(.easeInOut(duration: 0.2), value: activeZone)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Spacing.lg) {
        MetricCard(value: "287", unit: "W",   label: "Potenza",   zone: .z4)
        MetricCard(value: "165", unit: "bpm", label: "Frequenza", zone: .z3)
        MetricCard(value: "88",  unit: "rpm", label: "Cadenza",   zone: nil)
    }
    .padding()
    .background(Color.indigoBackground)
}
