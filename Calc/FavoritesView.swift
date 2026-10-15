import SwiftUI
import MapKit

struct Place: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var region: String
    var latitude: Double
    var longitude: Double
    var timeZoneID: String?

    var timeZone: TimeZone { timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current }
    var key: String { "\(name)|\(region)" }
}

@Observable
final class FavoritesStore {
    private static let defaultsKey = "favoritePlaces"
    var places: [Place] {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let list = try? JSONDecoder().decode([Place].self, from: data) {
            places = list
        } else {
            places = []
        }
    }

    func contains(_ p: Place) -> Bool { places.contains { $0.key == p.key } }

    func toggle(_ p: Place) {
        if let i = places.firstIndex(where: { $0.key == p.key }) { places.remove(at: i) } else { places.append(p) }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(places) { UserDefaults.standard.set(data, forKey: Self.defaultsKey) }
    }
}

/// Saved cities and towns, with a search to add more and each place's local time.
struct FavoritesView: View {
    @State private var store = FavoritesStore()
    @State private var query = ""
    @State private var results: [Place] = []
    @State private var searching = false

    var body: some View {
        NavigationStack {
            List {
                if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    Section("Results") {
                        if results.isEmpty {
                            Text(searching ? "Searching…" : "No cities or towns found").foregroundStyle(.secondary)
                        }
                        ForEach(results) { place in
                            Button {
                                Haptics.tap()
                                withAnimation(.smooth) { store.toggle(place) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(place.name).foregroundStyle(.primary)
                                        Text(place.region).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: store.contains(place) ? "star.fill" : "star")
                                        .foregroundStyle(store.contains(place) ? Color.yellow : Color.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Saved") {
                    if store.places.isEmpty {
                        Text("Search for a city or town and tap its star to save it.").foregroundStyle(.secondary)
                    }
                    ForEach(store.places) { place in
                        PlaceRow(place: place)
                    }
                    .onDelete { store.places.remove(atOffsets: $0) }
                    .onMove { store.places.move(fromOffsets: $0, toOffset: $1) }
                }
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .navigationTitle("Favorites")
            .searchable(text: $query, prompt: "Search cities and towns")
            .toolbar { if !store.places.isEmpty { EditButton() } }
            .task(id: query) { await search() }
        }
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { results = []; return }
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }
        searching = true
        defer { searching = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = q
        request.resultTypes = .address
        guard let response = try? await MKLocalSearch(request: request).start() else { results = []; return }
        var seen = Set<String>()
        results = response.mapItems.compactMap { item -> Place? in
            let pm = item.placemark
            guard let city = pm.locality else { return nil }
            let region = [pm.administrativeArea, pm.country].compactMap { $0 }.joined(separator: ", ")
            let place = Place(name: city, region: region,
                              latitude: pm.coordinate.latitude, longitude: pm.coordinate.longitude,
                              timeZoneID: (pm.timeZone ?? item.timeZone)?.identifier)
            return seen.insert(place.key).inserted ? place : nil
        }
    }
}

private struct PlaceRow: View {
    let place: Place

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            let cal = { () -> Calendar in var c = Calendar.current; c.timeZone = place.timeZone; return c }()
            let hour = cal.component(.hour, from: timeline.date)
            let day = (6..<18).contains(hour)
            HStack(spacing: 12) {
                Image(systemName: day ? "sun.max.fill" : "moon.stars.fill")
                    .foregroundStyle(day ? Color.orange : Color.indigo)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name).font(.headline)
                    Text(place.region).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(timeline.date, format: .dateTime.hour().minute().timeZone(place.timeZone))
                        .font(.system(.title3, design: .rounded, weight: .medium))
                    Text(offsetLabel(at: timeline.date)).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func offsetLabel(at date: Date) -> String {
        let diff = (place.timeZone.secondsFromGMT(for: date) - TimeZone.current.secondsFromGMT(for: date)) / 60
        if diff == 0 { return "Same time" }
        let h = abs(diff) / 60, m = abs(diff) % 60
        return (diff > 0 ? "+" : "−") + (m == 0 ? "\(h)h" : "\(h)h \(m)m")
    }
}
