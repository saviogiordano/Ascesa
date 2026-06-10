import SwiftUI

struct WatchContentView: View {
    var body: some View {
        VStack(spacing: 4) {
            Label("CARDIO", systemImage: "heart.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)

            Text("--")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("bpm")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
