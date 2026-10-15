import SwiftUI

struct KeyButton: View {
    enum Style { case digit, function, op, equals, sci, sciActive }

    let label: String
    var systemImage: String? = nil
    var style: Style = .digit
    var height: CGFloat = 60
    let action: () -> Void

    @Environment(\.appAccent) private var accent
    @AppStorage("haptics") private var haptics = true

    var body: some View {
        Button {
            if haptics { Haptics.tap() }
            action()
        } label: {
            Group {
                if let systemImage { Image(systemName: systemImage) } else { Text(label) }
            }
            .font(.system(size: isSci ? 17 : 26, weight: .medium, design: .rounded))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(glass, in: Capsule())
    }

    private var isSci: Bool { style == .sci || style == .sciActive }

    private var foreground: Color {
        switch style {
        case .op, .equals, .sciActive: return .white
        case .function: return accent
        default: return .primary
        }
    }

    private var glass: Glass {
        switch style {
        case .op: return .regular.tint(accent.opacity(0.75)).interactive()
        case .equals: return .regular.tint(accent).interactive()
        case .sciActive: return .regular.tint(accent.opacity(0.6)).interactive()
        default: return .regular.interactive()
        }
    }
}

struct CalculatorView: View {
    @State private var model = CalculatorModel()
    @State private var second = false
    @State private var showHistory = false
    @State private var showAdvanced = false

    @Environment(\.appAccent) private var accent
    @AppStorage("angle") private var angle: AngleMode = .degrees
    @AppStorage("precision") private var precision = 12
    @AppStorage("haptics") private var haptics = true
    @AppStorage("showScientific") private var showScientific = UIScreen.main.bounds.height >= 800

    var body: some View {
        VStack(spacing: 12) {
            topBar
            display
            if showScientific { sciPad.transition(.move(edge: .bottom).combined(with: .opacity)) }
            mainPad
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background { AppBackground() }
        .onAppear { sync() }
        .onChange(of: angle) { sync() }
        .onChange(of: precision) { sync() }
        .sheet(isPresented: $showHistory) { historySheet }
        .sheet(isPresented: $showAdvanced) { AdvancedMathSheet(model: model) }
    }

    private func sync() {
        model.configure(angle: angle, digits: precision)
    }

    // MARK: Top bar & display

    private var topBar: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                pill(systemImage: "clock.arrow.circlepath") { showHistory = true }
                pill(systemImage: "sum") { showAdvanced = true }
                Spacer()
                pill(text: angle.label) { angle = angle == .degrees ? .radians : .degrees }
                pill(systemImage: "function", active: showScientific) {
                    withAnimation(.smooth) { showScientific.toggle() }
                }
            }
        }
        .padding(.top, 8)
    }

    private func pill(text: String? = nil, systemImage: String? = nil, active: Bool = false,
                      action: @escaping () -> Void) -> some View {
        Button {
            if haptics { Haptics.tap() }
            action()
        } label: {
            Group {
                if let systemImage { Image(systemName: systemImage) } else { Text(text ?? "") }
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(active ? Color.white : Color.primary)
            .frame(minWidth: 44, minHeight: 36)
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .glassEffect(active ? .regular.tint(accent).interactive() : .regular.interactive(), in: Capsule())
    }

    private var display: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Spacer(minLength: 0)
            Text(model.preview.isEmpty ? " " : model.preview)
                .font(.system(size: 28, weight: .regular, design: .rounded))
                .foregroundStyle(model.preview == "Error" ? Color.red : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(model.expression.isEmpty ? "0" : model.expression)
                .font(.system(size: 64, weight: .light, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.35)
                .multilineTextAlignment(.trailing)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, 8)
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = model.preview.isEmpty ? model.expression : model.preview
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Keys

    private func key(_ label: String, _ style: KeyButton.Style = .digit, height: CGFloat = 60,
                     insert: String? = nil) -> some View {
        KeyButton(label: label, style: style, height: height) { model.input(insert ?? label) }
    }

    private func sci(_ label: String, _ insert: String) -> some View {
        KeyButton(label: label, style: .sci, height: 40) { model.input(insert) }
    }

    private var sciPad: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    KeyButton(label: "2nd", style: second ? .sciActive : .sci, height: 40) { second.toggle() }
                    sci("(", "(")
                    sci(")", ")")
                    sci("x²", "^2")
                    sci("xʸ", "^")
                }
                HStack(spacing: 8) {
                    sci(second ? "sin⁻¹" : "sin", second ? "asin(" : "sin(")
                    sci(second ? "cos⁻¹" : "cos", second ? "acos(" : "cos(")
                    sci(second ? "tan⁻¹" : "tan", second ? "atan(" : "tan(")
                    sci(second ? "eˣ" : "ln", second ? "exp(" : "ln(")
                    sci(second ? "sinh" : "log", second ? "sinh(" : "log(")
                }
                HStack(spacing: 8) {
                    sci(second ? "∛" : "√", second ? "∛(" : "√(")
                    sci("x!", "!")
                    sci("1/x", "^(-1)")
                    sci("π", "π")
                    sci("e", "e")
                }
            }
        }
    }

    private var mainPad: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    KeyButton(label: "AC", style: .function) { model.clear() }
                    KeyButton(label: "", systemImage: "plus.forwardslash.minus", style: .function) { model.negate() }
                    key("%", .function)
                    key("÷", .op)
                }
                HStack(spacing: 10) { key("7"); key("8"); key("9"); key("×", .op) }
                HStack(spacing: 10) { key("4"); key("5"); key("6"); key("−", .op) }
                HStack(spacing: 10) { key("1"); key("2"); key("3"); key("+", .op) }
                HStack(spacing: 10) {
                    key("0")
                    key(".")
                    KeyButton(label: "", systemImage: "delete.backward") { model.backspace() }
                    KeyButton(label: "=", style: .equals) {
                        if !model.equals() && haptics { Haptics.error() }
                    }
                }
            }
        }
    }

    // MARK: History

    private var historySheet: some View {
        NavigationStack {
            Group {
                if model.history.isEmpty {
                    ContentUnavailableView("No History", systemImage: "clock",
                                           description: Text("Your calculations will appear here."))
                } else {
                    List(model.history) { item in
                        Button {
                            model.restore(item)
                            showHistory = false
                        } label: {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(item.expression).font(.subheadline).foregroundStyle(.secondary)
                                Text(item.result).font(.title2.weight(.medium))
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear", role: .destructive) { model.history.removeAll() }
                        .disabled(model.history.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showHistory = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
