import SwiftUI

/// One "Graph" tab hosting the 2D, 3D and complex-plane graphers behind a switcher.
/// All three stay alive so each keeps its functions and viewport while you switch.
struct GraphHubView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case twoD = "2D", threeD = "3D", complex = "Complex"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .twoD
    @State private var fullscreen = false

    var body: some View {
        NavigationStack {
            ZStack {
                GraphView().visible(mode == .twoD)
                Graph3DView().visible(mode == .threeD)
                ComplexGraphView().visible(mode == .complex)
            }
            .background { AppBackground() }
            .environment(\.graphFullscreen, $fullscreen)
            .toolbar(fullscreen ? .hidden : .automatic, for: .tabBar)
            .toolbar(fullscreen ? .hidden : .automatic, for: .navigationBar)
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

// MARK: - Full screen

extension EnvironmentValues {
    @Entry var graphFullscreen: Binding<Bool> = .constant(false)
}

/// Page layout shared by the three graphers: padded and width-capped normally, edge to edge in full screen,
/// with a close button floating over the top corner.
struct GraphPage: ViewModifier {
    @Environment(\.graphFullscreen) private var fullscreen

    func body(content: Content) -> some View {
        let on = fullscreen.wrappedValue
        content
            .padding(.horizontal, on ? 0 : 16)
            .padding(.bottom, on ? 0 : 8)
            .frame(maxWidth: on ? .infinity : 720)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topTrailing) {
                if on {
                    Button {
                        withAnimation(.smooth) { fullscreen.wrappedValue = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .accessibilityLabel("Exit full screen")
                    .padding(12)
                }
            }
    }
}

/// Square-corner, edge-to-edge treatment for a graph surface while in full screen.
struct GraphSurface: ViewModifier {
    @Environment(\.graphFullscreen) private var fullscreen

    func body(content: Content) -> some View {
        let on = fullscreen.wrappedValue
        content
            .clipShape(.rect(cornerRadius: on ? 0 : 28))
            .glassEffect(on ? .identity : .regular, in: .rect(cornerRadius: on ? 0 : 28))
            .ignoresSafeArea(on ? .all : [])
    }
}

struct EnterFullscreenButton: View {
    @Environment(\.graphFullscreen) private var fullscreen

    var body: some View {
        Button {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            withAnimation(.smooth) { fullscreen.wrappedValue = true }
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel("Full screen")
        .opacity(fullscreen.wrappedValue ? 0 : 1)
    }
}
