import SwiftUI

struct ContentView: View {
    @AppStorage("appearance") private var appearance: AppearanceMode = .system
    @AppStorage("accent") private var accent: AccentChoice = .orange
    @AppStorage("customAccent") private var customHex = "FF2D55"

    var body: some View {
        TabView {
            Tab("Calculator", systemImage: "plus.forwardslash.minus") { CalculatorView() }
            Tab("Graph", systemImage: "chart.xyaxis.line") { GraphHubView() }
            Tab("Extras", systemImage: "square.grid.2x2") { ExtrasHubView() }
            Tab("Favorites", systemImage: "star") { FavoritesView() }
            Tab("Settings", systemImage: "gearshape") { SettingsView() }
        }
        .tint(accent.resolved(customHex: customHex))
        .environment(\.appAccent, accent.resolved(customHex: customHex))
        .preferredColorScheme(appearance.scheme)
    }
}
