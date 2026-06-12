import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Text("Home")
                .tabItem { Label("Home", systemImage: "house.fill") }
            Text("Percorsi")
                .tabItem { Label("Percorsi", systemImage: "map.fill") }
            Text("Allena")
                .tabItem { Label("Allena", systemImage: "bolt.fill") }
            Text("Storico")
                .tabItem { Label("Storico", systemImage: "clock.fill") }
            // DEBUG — sostituire con ProfileView
            BLEDebugView()
                .tabItem { Label("BLE Debug", systemImage: "antenna.radiowaves.left.and.right") }
            // DEBUG — rimuovere prima del rilascio
            RouteDebugView()
                .tabItem { Label("Route Debug", systemImage: "map") }
        }
        .tint(.amber)
    }
}
