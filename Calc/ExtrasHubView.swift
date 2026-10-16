import SwiftUI

/// All the Extras tools behind one dropdown menu. Pages are created the first time you visit them and
/// then kept alive, so each tool keeps its state when you switch away and back.
struct ExtrasHubView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case convert = "Convert", stats = "Stats"
        case fractals = "Fractals", pendulumFractal = "Pendulum Fractal", bifurcation = "Bifurcation Diagram"
        case hyperbolic = "Hyperbolic Tilings"
        case pendulum = "Pendulum", threeBody = "Three-Body Problem", attractors = "Strange Attractors"
        case cobweb = "Logistic Cobweb"
        case lissajous = "Lissajous Curves", rose = "Rose Curves", spirograph = "Spirograph"
        case spaceFilling = "Space-Filling Curves", epicycles = "Fourier Epicycles"
        case mobius = "Möbius & Klein", minimal = "Minimal Surfaces"
        case modular = "Modular Circle", ulam = "Ulam Spiral", sacks = "Sacks Spiral"
        case taylor = "Taylor Series", fourier = "Fourier Series"
        case life = "Game of Life", elementary = "Rule 30 & 110", langton = "Langton’s Ant", turing = "Turing Patterns"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .convert: return "arrow.left.arrow.right"
            case .stats: return "chart.bar"
            case .fractals: return "sparkles"
            case .pendulumFractal: return "square.grid.3x3.fill"
            case .bifurcation: return "chart.xyaxis.line"
            case .hyperbolic: return "circle.hexagongrid"
            case .pendulum: return "waveform.path"
            case .threeBody: return "circle.grid.cross"
            case .attractors: return "tornado"
            case .cobweb: return "point.topleft.down.to.point.bottomright.curvepath"
            case .lissajous: return "scribble"
            case .rose: return "camera.macro"
            case .spirograph: return "circle.dotted.and.circle"
            case .spaceFilling: return "square.dashed"
            case .epicycles: return "gearshape.2"
            case .mobius: return "infinity"
            case .minimal: return "drop"
            case .modular: return "heart"
            case .ulam: return "spiral"
            case .sacks: return "hurricane"
            case .taylor: return "function"
            case .fourier: return "waveform"
            case .life: return "square.grid.3x3"
            case .elementary: return "triangle"
            case .langton: return "ant"
            case .turing: return "leopard"
            }
        }
    }

    struct ModeGroup: Identifiable {
        let title: String
        let icon: String
        let modes: [Mode]
        var id: String { title }
    }

    static let topLevel: [Mode] = [.convert, .stats]
    static let groups: [ModeGroup] = [
        ModeGroup(title: "Fractals", icon: "sparkles", modes: [.fractals, .pendulumFractal, .bifurcation, .hyperbolic]),
        ModeGroup(title: "Chaos & Dynamics", icon: "tornado", modes: [.pendulum, .threeBody, .attractors, .cobweb]),
        ModeGroup(title: "Curves", icon: "scribble", modes: [.lissajous, .rose, .spirograph, .spaceFilling, .epicycles]),
        ModeGroup(title: "Surfaces", icon: "infinity", modes: [.mobius, .minimal]),
        ModeGroup(title: "Number Patterns & Series", icon: "number", modes: [.modular, .ulam, .sacks, .taylor, .fourier]),
        ModeGroup(title: "Automata & Patterns", icon: "square.grid.3x3", modes: [.life, .elementary, .langton, .turing]),
    ]

    @State private var mode: Mode = .convert
    @State private var visited: Set<Mode> = [.convert]
    @StateObject private var pendulum = PendulumModel()
    @Environment(\.extrasVisible) private var extrasVisible
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack {
                ForEach(Mode.allCases) { m in
                    if visited.contains(m) { page(m).visible(mode == m) }
                }
            }
            .environmentObject(pendulum)
            .background { AppBackground() }
            .onChange(of: mode) { _, new in
                visited.insert(new)
                // The pendulum's sound stops whenever you leave it: another mode, another tab, or the app.
                if new != .pendulum { pendulum.stopSound() }
            }
            .onChange(of: pendulum.launchTick) { _, _ in mode = .pendulum }
            .onChange(of: extrasVisible) { _, visible in if !visible { pendulum.stopSound() } }
            .onChange(of: scenePhase) { _, phase in if phase != .active { pendulum.stopSound() } }
            .onDisappear { pendulum.stopSound() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { switcher }
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

    private var switcher: some View {
        Menu {
            ForEach(Self.topLevel) { item($0) }
            ForEach(Self.groups) { g in
                Menu {
                    ForEach(g.modes) { item($0) }
                } label: {
                    Label(g.title, systemImage: g.icon)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode.icon)
                Text(mode.rawValue).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption.weight(.bold))
            }
            .font(.headline)
            .padding(.horizontal, 4)
        }
        .accessibilityLabel("Extras: \(mode.rawValue)")
    }

    private func item(_ m: Mode) -> some View {
        Button {
            mode = m
        } label: {
            Label(m.rawValue, systemImage: mode == m ? "checkmark" : m.icon)
        }
    }

    @ViewBuilder
    private func page(_ m: Mode) -> some View {
        let live = mode == m && extrasVisible
        switch m {
        case .convert: ConverterView()
        case .stats: StatsView()
        case .fractals: FractalView()
        case .pendulumFractal: PendulumFractalView(active: live)
        case .bifurcation: BifurcationView(active: live)
        case .hyperbolic: HyperbolicView()
        case .pendulum: PendulumSimulatorView(active: live)
        case .threeBody: ThreeBodyView(active: live)
        case .attractors: AttractorsView(active: live)
        case .cobweb: CobwebView()
        case .lissajous: LissajousView(active: live)
        case .rose: RoseView()
        case .spirograph: SpirographView(active: live)
        case .spaceFilling: SpaceFillingView()
        case .epicycles: EpicyclesView(active: live)
        case .mobius: SurfacesView(active: live, minimal: false)
        case .minimal: SurfacesView(active: live, minimal: true)
        case .modular: ModularCircleView(active: live)
        case .ulam: PrimeSpiralView(sacks: false)
        case .sacks: PrimeSpiralView(sacks: true)
        case .taylor: TaylorSeriesView()
        case .fourier: FourierSeriesView()
        case .life: LifeView(active: live)
        case .elementary: ElementaryAutomatonView(active: live)
        case .langton: LangtonView(active: live)
        case .turing: TuringView(active: live)
        }
    }
}
