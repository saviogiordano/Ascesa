import SwiftUI

@main
struct AscesaWatchApp: App {
    @State private var manager = WatchWorkoutManager()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environment(manager)
        }
    }
}
