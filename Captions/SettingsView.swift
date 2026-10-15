import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(HistoryStore.self) private var history
    @State private var confirmClear = false

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $settings.theme) {
                        ForEach(ThemeChoice.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Image(systemName: "textformat.size.smaller")
                        Slider(value: $settings.textSize, in: 20...56, step: 2)
                        Image(systemName: "textformat.size.larger")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Caption text size")
                    Text("Preview text")
                        .font(.system(size: settings.textSize, weight: .semibold))
                }
                .listRowBackground(Rectangle().fill(.ultraThinMaterial))

                Section("Accent Color") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(accentPresets, id: \.self) { hex in
                                Circle().fill(Color(hex: hex)).frame(width: 34, height: 34)
                                    .overlay {
                                        if settings.accentHex.uppercased() == hex {
                                            Circle().strokeBorder(Color(hex: hex), lineWidth: 2.5).padding(-5)
                                        }
                                    }
                                    .onTapGesture { settings.accentHex = hex; settings.tap() }
                                    .accessibilityLabel("Accent \(hex)")
                                    .accessibilityAddTraits(.isButton)
                            }
                        }
                        .padding(8)
                    }
                    ColorPicker("Custom Color", selection: Binding(
                        get: { settings.accent },
                        set: { settings.accentHex = $0.hex }
                    ), supportsOpacity: false)
                }
                .listRowBackground(Rectangle().fill(.ultraThinMaterial))

                Section {
                    Picker("Language", selection: $settings.languageCode) {
                        ForEach(languageOptions, id: \.code) { Text($0.name).tag($0.code) }
                    }
                    Toggle("Save to History", isOn: $settings.saveHistory)
                    Toggle("Haptic Feedback", isOn: $settings.haptics)
                } header: {
                    Text("Transcription")
                } footer: {
                    Text("Transcripts are stored only on this device.")
                }
                .listRowBackground(Rectangle().fill(.ultraThinMaterial))

                Section {
                    Button("Clear History…", role: .destructive) { confirmClear = true }
                }
                .listRowBackground(Rectangle().fill(.ultraThinMaterial))
            }
            .scrollContentBackground(.hidden)
            .background(AmbientBackground())
            .navigationTitle("Settings")
            .confirmationDialog("Delete all saved transcripts?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Delete All", role: .destructive) { history.clear() }
            }
        }
    }
}
