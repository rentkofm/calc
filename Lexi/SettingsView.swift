import SwiftUI

struct SettingsView: View {
    @Environment(LibraryStore.self) private var library
    @AppStorage("appearance") private var appearance: AppearanceMode = .system
    @AppStorage("accent") private var accent: AccentChoice = .blue
    @AppStorage("customAccent") private var customHex = "0A84FF"
    @AppStorage("haptics") private var haptics = true
    @AppStorage("showExamples") private var showExamples = true
    @State private var confirmReset = false

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
                                Circle().fill(Color(hex: customHex)).frame(width: 22, height: 22)
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

                Section("Dictionary") {
                    Toggle("Show Example Sentences", isOn: $showExamples)
                    Toggle("Haptic Feedback", isOn: $haptics)
                }

                Section("Data") {
                    Button("Clear History", role: .destructive) { library.clearHistory() }
                        .disabled(library.history.isEmpty)
                    Button("Clear Favorites", role: .destructive) { library.clearFavorites() }
                        .disabled(library.favorites.isEmpty)
                }

                Section {
                    Text("Lexi shows pronunciations as written symbols, with no audio. Definitions from dictionaryapi.dev, related words from Datamuse.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .navigationTitle("Settings")
        }
    }
}
