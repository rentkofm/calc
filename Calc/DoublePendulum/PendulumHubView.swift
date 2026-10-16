import SwiftUI

/// Double pendulum extras: a live simulator (with sound) and the flip-time fractal.
struct PendulumHubView: View {
    let active: Bool
    @StateObject private var model = PendulumModel()

    var body: some View {
        VStack(spacing: 0) {
            Picker("Pendulum", selection: $model.mode) {
                ForEach(PendulumModel.Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            ZStack {
                PendulumSimulatorView().visible(model.mode == .simulate)
                PendulumFractalView().visible(model.mode == .fractal)
            }
        }
        .environmentObject(model)
        .onAppear { model.hubActive = active }
        .onChange(of: active) { _, now in
            model.hubActive = now
            model.pause()
        }
    }
}
