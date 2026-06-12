import SwiftUI

struct WatchContentView: View {
    @Environment(WatchWorkoutManager.self) private var manager

    var body: some View {
        VStack(spacing: 4) {
            Label("CARDIO", systemImage: "heart.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)

            Text(manager.bpm > 0 ? "\(manager.bpm)" : "--")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: manager.bpm)

            Text("bpm")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let error = manager.errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .task { await manager.start() }
    }
}
