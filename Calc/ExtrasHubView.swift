import SwiftUI

/// Unit conversion, fractals, the double pendulum, formulas and stats, behind a dropdown menu.
struct ExtrasHubView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case convert = "Convert", fractals = "Fractals", pendulum = "Pendulum",
             pendulumFractal = "Pendulum Fractal", formulas = "Formulas", stats = "Stats"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .convert: return "arrow.left.arrow.right"
            case .fractals: return "sparkles"
            case .pendulum: return "waveform.path"
            case .pendulumFractal: return "square.grid.3x3.fill"
            case .formulas: return "function"
            case .stats: return "chart.bar"
            }
        }
    }

    @State private var mode: Mode = .convert
    @StateObject private var pendulum = PendulumModel()

    var body: some View {
        NavigationStack {
            ZStack {
                ConverterView().visible(mode == .convert)
                FractalView().visible(mode == .fractals)
                PendulumSimulatorView(active: mode == .pendulum).visible(mode == .pendulum)
                PendulumFractalView(active: mode == .pendulumFractal).visible(mode == .pendulumFractal)
                FormulasView().visible(mode == .formulas)
                StatsView().visible(mode == .stats)
            }
            .environmentObject(pendulum)
            .background { AppBackground() }
            .onChange(of: pendulum.launchTick) { _, _ in mode = .pendulum }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Menu {
                        Picker("Extras", selection: $mode) {
                            ForEach(Mode.allCases) { Label($0.rawValue, systemImage: $0.icon).tag($0) }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mode.icon)
                            Text(mode.rawValue)
                            Image(systemName: "chevron.down").font(.caption.weight(.bold))
                        }
                        .font(.headline)
                        .padding(.horizontal, 4)
                    }
                    .accessibilityLabel("Extras: \(mode.rawValue)")
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
