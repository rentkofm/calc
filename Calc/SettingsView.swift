import SwiftUI

struct SettingsView: View {
    @AppStorage("appearance") private var appearance: AppearanceMode = .system
    @AppStorage("accent") private var accent: AccentChoice = .orange
    @AppStorage("customAccent") private var customHex = "FF2D55"
    @AppStorage("angle") private var angle: AngleMode = .degrees
    @AppStorage("precision") private var precision = 12
    @AppStorage("haptics") private var haptics = true
    @AppStorage("showScientific") private var showScientific = true
    @AppStorage("graphGrid") private var graphGrid = true
    @AppStorage("starDensity") private var starDensity = 0.5
    @AppStorage("starTwinkle") private var starTwinkle = 0.5

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        ForEach(AppearanceMode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Accent Color")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 14) {
                            ForEach(AccentChoice.presets) { choice in
                                Button {
                                    withAnimation(.smooth) { accent = choice }
                                } label: {
                                    Circle()
                                        .fill(choice.color.gradient)
                                        .frame(width: 38, height: 38)
                                        .overlay {
                                            if accent == choice {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .glassEffect(.regular.interactive(), in: Circle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(choice.label)
                            }
                        }
                    }
                    .padding(.vertical, 6)

                    HStack {
                        Button {
                            accent = .custom
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(hex: customHex))
                                    .frame(width: 22, height: 22)
                                Text("Custom Color")
                                if accent == .custom {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.primary)
                        Spacer()
                        ColorPicker("Custom Color", selection: Binding(
                            get: { Color(hex: customHex) },
                            set: { customHex = $0.hex; accent = .custom }
                        ), supportsOpacity: false)
                        .labelsHidden()
                    }
                }

                Section {
                    LabeledContent("Star Density") {
                        Slider(value: $starDensity, in: 0...1).frame(maxWidth: 180)
                    }
                    LabeledContent("Star Twinkle") {
                        Slider(value: $starTwinkle, in: 0...1).frame(maxWidth: 180)
                    }
                } header: {
                    Text("Night Sky")
                } footer: {
                    Text("Stars and the lit city skyline appear in dark mode.")
                }

                Section("Calculator") {
                    Picker("Angle Unit", selection: $angle) {
                        ForEach(AngleMode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Stepper("Precision: \(precision) digits", value: $precision, in: 6...15)
                    Toggle("Show Scientific Keys", isOn: $showScientific)
                    Toggle("Haptic Feedback", isOn: $haptics)
                }

                Section {
                    Toggle("Show Grid", isOn: $graphGrid)
                } header: {
                    Text("Graph")
                } footer: {
                    Text("Graphs always use radians.")
                }

                Section {
                    Button("Reset All Settings", role: .destructive) {
                        appearance = .system; accent = .orange; customHex = "FF2D55"; angle = .degrees
                        precision = 12; haptics = true; showScientific = true; graphGrid = true
                        starDensity = 0.5; starTwinkle = 0.5
                    }
                }

                Section {
                    LabeledContent("Version", value: "1.0")
                }
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .navigationTitle("Settings")
        }
    }
}
