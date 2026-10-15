import SwiftUI

@main
struct CaptionsApp: App {
    @State private var settings = AppSettings()
    @State private var history = HistoryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(history)
        }
    }
}

struct ContentView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        TabView {
            Tab("Transcribe", systemImage: "mic.fill") { TranscribeView() }
            Tab("History", systemImage: "clock") { HistoryView() }
            Tab("Settings", systemImage: "slider.horizontal.3") { SettingsView() }
        }
        .tint(settings.accent)
        .preferredColorScheme(settings.theme.scheme)
    }
}

/// Soft accent-tinted backdrop so the glass has something to refract.
struct AmbientBackground: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        ZStack {
            Color(.systemBackground)
            Circle().fill(settings.accent.opacity(0.45))
                .frame(width: 420, height: 420).blur(radius: 90).offset(x: -120, y: -260)
            Circle().fill(settings.accent.opacity(0.3)).hueRotation(.degrees(50))
                .frame(width: 360, height: 360).blur(radius: 100).offset(x: 140, y: 300)
        }
        .ignoresSafeArea()
    }
}
