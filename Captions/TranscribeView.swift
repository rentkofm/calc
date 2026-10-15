import SwiftUI

struct TranscribeView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(HistoryStore.self) private var history
    @State private var transcriber = Transcriber()

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        caption
                        Color.clear.frame(height: 1).id("end")
                    }
                    .padding(.horizontal)
                }
                .onChange(of: transcriber.text) { proxy.scrollTo("end") }
            }
            .background(AmbientBackground())
            .navigationTitle("Captions")
            .safeAreaInset(edge: .bottom) { micButton.padding(.bottom, 8) }
            .alert("Can’t Listen", isPresented: .constant(transcriber.errorMessage != nil)) {
                Button("OK") { transcriber.errorMessage = nil }
            } message: {
                Text(transcriber.errorMessage ?? "")
            }
        }
    }

    private var caption: some View {
        Group {
            if transcriber.text.isEmpty {
                Text(transcriber.isListening ? "Listening…" : "Tap Listen to start transcribing speech around you.")
                    .foregroundStyle(.secondary)
            } else {
                Text(transcriber.text)
            }
        }
        .font(.system(size: settings.textSize, weight: .semibold))
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var micButton: some View {
        Button {
            settings.tap()
            if transcriber.isListening {
                let text = transcriber.stop()
                if settings.saveHistory { history.add(text) }
            } else {
                Task { await transcriber.start(localeID: settings.languageCode) }
            }
        } label: {
            Label(transcriber.isListening ? "Stop" : "Listen",
                  systemImage: transcriber.isListening ? "stop.fill" : "mic.fill")
                .font(.headline)
                .padding(.horizontal, 14).padding(.vertical, 8)
        }
        .buttonStyle(.glassProminent)
        .tint(transcriber.isListening ? .red : settings.accent)
        .controlSize(.large)
    }
}
