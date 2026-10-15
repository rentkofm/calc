import SwiftUI

/// Unit conversion plus fractals, behind a switcher.
struct ExtrasHubView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case convert = "Convert", fractals = "Fractals", formulas = "Formulas"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .convert

    var body: some View {
        NavigationStack {
            ZStack {
                ConverterView().visible(mode == .convert)
                FractalView().visible(mode == .fractals)
                FormulasView().visible(mode == .formulas)
            }
            .background { AppBackground() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Extras", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
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
