import Foundation
import Observation

struct HistoryItem: Codable, Identifiable, Hashable {
    var id: String { word }
    let word: String
    var date: Date
}

/// Search history and favorite words, saved on device.
@MainActor @Observable
final class LibraryStore {
    private(set) var history: [HistoryItem] = []
    private(set) var favorites: [String] = []

    private let defaults = UserDefaults.standard

    init() {
        if let data = defaults.data(forKey: "history"),
           let items = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            history = items
        }
        favorites = defaults.stringArray(forKey: "favorites") ?? []
    }

    func record(_ word: String) {
        let w = word.lowercased()
        history.removeAll { $0.word == w }
        history.insert(HistoryItem(word: w, date: .now), at: 0)
        if history.count > 200 { history.removeLast(history.count - 200) }
        saveHistory()
    }

    func removeHistory(at offsets: IndexSet) {
        history.remove(atOffsets: offsets)
        saveHistory()
    }

    func clearHistory() {
        history = []
        saveHistory()
    }

    func isFavorite(_ word: String) -> Bool { favorites.contains(word.lowercased()) }

    @discardableResult
    func toggleFavorite(_ word: String) -> Bool {
        let w = word.lowercased()
        if let i = favorites.firstIndex(of: w) {
            favorites.remove(at: i)
        } else {
            favorites.insert(w, at: 0)
        }
        saveFavorites()
        return favorites.contains(w)
    }

    func removeFavorites(at offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        saveFavorites()
    }

    func clearFavorites() {
        favorites = []
        saveFavorites()
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) { defaults.set(data, forKey: "history") }
    }

    private func saveFavorites() {
        defaults.set(favorites, forKey: "favorites")
    }
}
