import SwiftUI

struct ContentView: View {
    @AppStorage("appearance") private var appearance: AppearanceMode = .system
    @AppStorage("accent") private var accent: AccentChoice = .orange
    @AppStorage("customAccent") private var customHex = "FF2D55"

    var body: some View {
        TabView {
            Tab("Calculator", systemImage: "plus.forwardslash.minus") { CalculatorView() }
            Tab("Graph", systemImage: "chart.xyaxis.line") { GraphHubView() }
            Tab("Convert", systemImage: "arrow.left.arrow.right") { ConverterView() }
            Tab("Settings", systemImage: "gearshape") { SettingsView() }
        }
        .tint(accent.resolved(customHex: customHex))
        .environment(\.appAccent, accent.resolved(customHex: customHex))
        .preferredColorScheme(appearance.scheme)
    }
}
