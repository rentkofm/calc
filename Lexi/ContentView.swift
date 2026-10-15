import SwiftUI

struct ContentView: View {
    @AppStorage("appearance") private var appearance: AppearanceMode = .system
    @AppStorage("accent") private var accent: AccentChoice = .blue
    @AppStorage("customAccent") private var customHex = "0A84FF"

    var body: some View {
        let color = accent.resolved(customHex: customHex)
        TabView {
            Tab("Search", systemImage: "magnifyingglass") { SearchTab() }
            Tab("Favorites", systemImage: "heart") { FavoritesTab() }
            Tab("History", systemImage: "clock") { HistoryTab() }
            Tab("Settings", systemImage: "gearshape") { SettingsView() }
        }
        .tint(color)
        .environment(\.appAccent, color)
        .preferredColorScheme(appearance.scheme)
    }
}

// MARK: - Search

struct SearchTab: View {
    @Environment(LibraryStore.self) private var library
    @State private var path: [String] = []
    @State private var query = ""
    @State private var suggestions: [String] = []

    private let ideas = ["serendipity", "ephemeral", "luminous", "resilient", "whisper", "eloquent"]

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    if !library.history.isEmpty {
                        Section("Recent") {
                            ForEach(library.history.prefix(6)) { row($0.word, "clock") }
                        }
                    }
                    Section("Try a Word") {
                        ForEach(ideas, id: \.self) { row($0, "sparkles") }
                    }
                } else {
                    ForEach(suggestions, id: \.self) { row($0, "magnifyingglass") }
                }
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .navigationTitle("Lexi")
            .searchable(text: $query, prompt: "Search a word")
            .onSubmit(of: .search) {
                let w = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if !w.isEmpty { path.append(w) }
            }
            .navigationDestination(for: String.self) { WordDetailView(word: $0) }
            .task(id: query) {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                suggestions = await DictionaryService.suggestions(query)
            }
        }
    }

    private func row(_ word: String, _ icon: String) -> some View {
        NavigationLink(value: word) {
            Label(word, systemImage: icon)
        }
        .listRowBackground(Rectangle().fill(.ultraThinMaterial))
    }
}

// MARK: - Favorites & History

struct FavoritesTab: View {
    @Environment(LibraryStore.self) private var library

    var body: some View {
        NavigationStack {
            Group {
                if library.favorites.isEmpty {
                    ContentUnavailableView("No Favorites Yet",
                                           systemImage: "heart",
                                           description: Text("Tap the heart on any word to save it here."))
                } else {
                    List {
                        ForEach(library.favorites, id: \.self) { word in
                            NavigationLink(value: word) { Text(word).font(.title3) }
                                .listRowBackground(Rectangle().fill(.ultraThinMaterial))
                        }
                        .onDelete(perform: library.removeFavorites)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background { AppBackground() }
            .navigationTitle("Favorites")
            .navigationDestination(for: String.self) { WordDetailView(word: $0) }
            .toolbar {
                if !library.favorites.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) { EditButton() }
                }
            }
        }
    }
}

struct HistoryTab: View {
    @Environment(LibraryStore.self) private var library
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            Group {
                if library.history.isEmpty {
                    ContentUnavailableView("No History",
                                           systemImage: "clock",
                                           description: Text("Words you look up will appear here."))
                } else {
                    List {
                        ForEach(library.history) { item in
                            NavigationLink(value: item.word) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.word).font(.title3)
                                    Text(item.date, style: .relative)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .listRowBackground(Rectangle().fill(.ultraThinMaterial))
                        }
                        .onDelete(perform: library.removeHistory)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background { AppBackground() }
            .navigationTitle("History")
            .navigationDestination(for: String.self) { WordDetailView(word: $0) }
            .toolbar {
                if !library.history.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") { confirmClear = true }
                    }
                }
            }
            .confirmationDialog("Clear all history?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) { library.clearHistory() }
            }
        }
    }
}
