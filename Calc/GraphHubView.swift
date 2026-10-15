import SwiftUI

/// One "Graph" tab hosting the 2D, 3D and complex-plane graphers behind a switcher.
/// All three stay alive so each keeps its functions and viewport while you switch.
struct GraphHubView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case twoD = "2D", threeD = "3D", complex = "Complex"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .twoD

    var body: some View {
        NavigationStack {
            ZStack {
                GraphView().visible(mode == .twoD)
                Graph3DView().visible(mode == .threeD)
                ComplexGraphView().visible(mode == .complex)
            }
            .background { AppBackground() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Graph type", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)
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

extension View {
    func visible(_ on: Bool) -> some View {
        opacity(on ? 1 : 0)
            .allowsHitTesting(on)
            .accessibilityHidden(!on)
    }
}
