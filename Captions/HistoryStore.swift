import Foundation
import Observation

struct Transcript: Identifiable, Codable, Hashable {
    var id = UUID()
    var date = Date()
    var text: String
}

@MainActor @Observable
final class HistoryStore {
    private static let key = "history"

    var items: [Transcript] {
        didSet { if let data = try? JSONEncoder().encode(items) { UserDefaults.standard.set(data, forKey: Self.key) } }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([Transcript].self, from: data) {
            items = saved
        } else {
            items = []
        }
    }

    func add(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        items.insert(Transcript(text: t), at: 0)
    }

    func delete(ids: Set<UUID>) { items.removeAll { ids.contains($0.id) } }
    func clear() { items.removeAll() }
}
