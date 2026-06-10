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
            Text("Profilo")
                .tabItem { Label("Profilo", systemImage: "person.fill") }
        }
        .tint(.amber)
    }
}
