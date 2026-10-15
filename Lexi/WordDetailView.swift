import SwiftUI

struct WordDetailView: View {
    let word: String

    @Environment(LibraryStore.self) private var library
    @AppStorage("haptics") private var haptics = true
    @AppStorage("showExamples") private var showExamples = true

    private enum Phase {
        case loading
        case loaded(WordResult)
        case notFound([String])
        case offline
    }

    @State private var phase: Phase = .loading
    @State private var showKey = false

    private var key: String { word.lowercased() }

    var body: some View {
        ScrollView {
            switch phase {
            case .loading:
                ProgressView().controlSize(.large).padding(.top, 120)
            case .loaded(let result):
                content(result)
            case .notFound(let suggestions):
                notFound(suggestions)
            case .offline:
                ContentUnavailableView {
                    Label("Can't Reach the Dictionary", systemImage: "wifi.slash")
                } description: {
                    Text("Check your connection and try again.")
                } actions: {
                    Button("Try Again") { Task { await load() } }
                        .buttonStyle(.glass)
                }
                .padding(.top, 60)
            }
        }
        .background { AppBackground() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let added = library.toggleFavorite(key)
                    if haptics { added ? Haptics.success() : Haptics.tap() }
                } label: {
                    Image(systemName: library.isFavorite(key) ? "heart.fill" : "heart")
                }
                .accessibilityLabel(library.isFavorite(key) ? "Remove from favorites" : "Add to favorites")
            }
        }
        .sheet(isPresented: $showKey) { PronunciationKeyView() }
        .task(id: word) { await load() }
    }

    // MARK: - Content

    private func content(_ r: WordResult) -> some View {
        GlassEffectContainer(spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                header(r)
                ForEach(Array(groupedMeanings(r).enumerated()), id: \.offset) { _, group in
                    card(group.pos) {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(Array(group.definitions.enumerated()), id: \.offset) { i, def in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(i + 1). \(def.definition)")
                                    if showExamples, let ex = def.example, !ex.isEmpty {
                                        Text("“\(ex)”")
                                            .font(.subheadline.italic())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                chips("Synonyms", r.synonyms)
                chips("Antonyms", r.antonyms)
                chips("Related Words", r.related)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func header(_ r: WordResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(r.word)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(2)

            if r.pronunciations.isEmpty {
                Text("No pronunciation available")
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(r.pronunciations, id: \.self) { p in
                            Text(p).font(.title2).foregroundStyle(.tint)
                        }
                    }
                    Spacer()
                    Button { showKey = true } label: {
                        Label("Sound Guide", systemImage: "character.book.closed")
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .padding(10)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .accessibilityLabel("Sound guide")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
    }

    private struct MeaningGroup { let pos: String; var definitions: [Definition] }

    private func groupedMeanings(_ r: WordResult) -> [MeaningGroup] {
        var groups: [MeaningGroup] = []
        for m in r.meanings {
            if let i = groups.firstIndex(where: { $0.pos == m.partOfSpeech }) {
                groups[i].definitions += m.definitions
            } else {
                groups.append(MeaningGroup(pos: m.partOfSpeech, definitions: m.definitions))
            }
        }
        return groups.map { MeaningGroup(pos: $0.pos, definitions: Array($0.definitions.prefix(4))) }
    }

    private func card<Body: View>(_ title: String, @ViewBuilder _ body: () -> Body) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold).italic())
                .foregroundStyle(.tint)
            body()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
    }

    @ViewBuilder
    private func chips(_ title: String, _ words: [String]) -> some View {
        if !words.isEmpty {
            card(title) {
                FlowLayout(spacing: 8) {
                    ForEach(words, id: \.self) { w in
                        NavigationLink(value: w) {
                            Text(w)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: Capsule())
                    }
                }
            }
        }
    }

    private func notFound(_ suggestions: [String]) -> some View {
        VStack(spacing: 20) {
            ContentUnavailableView("No Entry for “\(word)”",
                                   systemImage: "text.magnifyingglass",
                                   description: Text("Check the spelling or try another word."))
            if !suggestions.isEmpty {
                Text("Did you mean").font(.headline)
                FlowLayout(spacing: 8) {
                    ForEach(suggestions, id: \.self) { w in
                        NavigationLink(value: w) {
                            Text(w).padding(.horizontal, 14).padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: Capsule())
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 40)
    }

    // MARK: - Loading

    private func load() async {
        phase = .loading
        do {
            let result = try await DictionaryService.lookup(word)
            phase = .loaded(result)
            library.record(result.word)
        } catch LookupError.notFound {
            phase = .notFound(await DictionaryService.suggestions(word).filter { $0.lowercased() != key })
        } catch {
            if !Task.isCancelled { phase = .offline }
        }
    }
}

/// Plain-language guide to the pronunciation symbols.
struct PronunciationKeyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Pronunciations are written in IPA, a spelling system for sounds. Each symbol stands for one sound, shown with a word that has it.")
                        .foregroundStyle(.secondary)
                }
                section("Vowels", IPAKey.vowels)
                section("Consonants", IPAKey.consonants)
                section("Marks", IPAKey.marks)
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .navigationTitle("Sound Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func section(_ title: String, _ rows: [(String, String)]) -> some View {
        Section(title) {
            ForEach(rows, id: \.0) { symbol, example in
                HStack {
                    Text(symbol).font(.title3).foregroundStyle(.tint).frame(width: 90, alignment: .leading)
                    Text(example)
                    Spacer()
                }
            }
        }
    }
}
