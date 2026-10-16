import SwiftUI

/// Unit conversion, fractals, the double pendulum, formulas and stats, behind a switcher.
struct ExtrasHubView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case convert = "Convert", fractals = "Fractals", pendulum = "Pendulum", formulas = "Formulas", stats = "Stats"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .convert

    var body: some View {
        NavigationStack {
            ZStack {
                ConverterView().visible(mode == .convert)
                FractalView().visible(mode == .fractals)
                PendulumHubView(active: mode == .pendulum).visible(mode == .pendulum)
                FormulasView().visible(mode == .formulas)
                StatsView().visible(mode == .stats)
            }
            .background { AppBackground() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Extras", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 420)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                        to: nil, from: nil, for: nil)
                    }
                }
            }
        }
    }
}
