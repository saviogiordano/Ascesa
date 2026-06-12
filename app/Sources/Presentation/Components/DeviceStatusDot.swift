import SwiftUI

enum DeviceConnectionStatus: Equatable {
    case connected
    case scanning
    case disconnected

    var label: String {
        switch self {
        case .connected:    "Connesso"
        case .scanning:     "Ricerca…"
        case .disconnected: "Disconnesso"
        }
    }

    var color: Color {
        switch self {
        case .connected:    .green
        case .scanning:     .orange
        case .disconnected: Color(white: 0.45)
        }
    }
}

/// A small coloured indicator dot for device connection state.
/// Green = connected, orange = scanning, grey = disconnected.
struct DeviceStatusDot: View {
    let status: DeviceConnectionStatus
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: size, height: size)
            .shadow(color: status == .connected ? .green.opacity(0.6) : .clear, radius: 3)
            .animation(.easeInOut(duration: 0.3), value: status)
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        ForEach([DeviceConnectionStatus.connected, .scanning, .disconnected], id: \.label) { status in
            HStack(spacing: Spacing.sm) {
                DeviceStatusDot(status: status)
                Text(status.label)
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
            }
        }
    }
    .padding()
    .background(Color.indigoBackground)
}
