import SwiftUI

/// A pill-shaped badge that shows the current training zone with its colour.
struct ZoneBadge: View {
    let zone: Zone

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(zone.color)
                .frame(width: 7, height: 7)
            Text(zone.label)
                .font(Typography.metricLabel)
                .tracking(0.4)
                .textCase(.uppercase)
        }
        .foregroundStyle(zone.color)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs + 2)
        .background(zone.color.opacity(0.18), in: Capsule())
        .overlay(Capsule().strokeBorder(zone.color.opacity(0.35), lineWidth: 1))
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: Spacing.md) {
        ForEach(Zone.allCases, id: \.self) { zone in
            ZoneBadge(zone: zone)
        }
    }
    .padding()
    .background(Color.indigoBackground)
}
