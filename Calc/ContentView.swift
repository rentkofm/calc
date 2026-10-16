import SwiftUI

extension EnvironmentValues {
    /// True while the Extras tab is the selected tab.
    @Entry var extrasVisible: Bool = true
}

struct ContentView: View {
    enum AppTab: Hashable { case calculator, graph, extras, reference }
    @State private var selectedTab: AppTab = .calculator
    @AppStorage("appearance") private var appearance: AppearanceMode = .system
    @AppStorage("accent") private var accent: AccentChoice = .orange
    @AppStorage("customAccent") private var customHex = "FF2D55"

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Calculator", systemImage: "plus.forwardslash.minus", value: AppTab.calculator) { CalculatorView() }
            Tab("Graph", systemImage: "chart.xyaxis.line", value: AppTab.graph) { GraphHubView() }
            Tab("Extras", systemImage: "square.grid.2x2", value: AppTab.extras) { ExtrasHubView() }
            Tab("Reference", systemImage: "books.vertical", value: AppTab.reference) { ReferenceView() }
        }
        .environment(\.extrasVisible, selectedTab == .extras)
        .tint(accent.resolved(customHex: customHex))
        .environment(\.appAccent, accent.resolved(customHex: customHex))
        .preferredColorScheme(appearance.scheme)
    }
}
