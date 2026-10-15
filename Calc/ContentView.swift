import SwiftUI

struct ContentView: View {
    @AppStorage("appearance") private var appearance: AppearanceMode = .system
    @AppStorage("accent") private var accent: AccentChoice = .orange

    var body: some View {
        TabView {
            Tab("Calculator", systemImage: "plus.forwardslash.minus") { CalculatorView() }
            Tab("Graph", systemImage: "chart.xyaxis.line") { GraphView() }
            Tab("Convert", systemImage: "arrow.left.arrow.right") { ConverterView() }
            Tab("Settings", systemImage: "gearshape") { SettingsView() }
        }
        .tint(accent.color)
        .environment(\.appAccent, accent.color)
        .preferredColorScheme(appearance.scheme)
    }
}
