import SwiftUI

struct SettingsView: View {
    @AppStorage("appearance") private var appearance: AppearanceMode = .system
    @AppStorage("accent") private var accent: AccentChoice = .orange
    @AppStorage("angle") private var angle: AngleMode = .degrees
    @AppStorage("precision") private var precision = 12
    @AppStorage("haptics") private var haptics = true
    @AppStorage("showScientific") private var showScientific = true
    @AppStorage("graphGrid") private var graphGrid = true

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
                            ForEach(AccentChoice.allCases) { choice in
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

                Section("Graph") {
                    Toggle("Show Grid", isOn: $graphGrid)
                } footer: {
                    Text("Graphs always use radians.")
                }

                Section {
                    Button("Reset All Settings", role: .destructive) {
                        appearance = .system; accent = .orange; angle = .degrees
                        precision = 12; haptics = true; showScientific = true; graphGrid = true
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
