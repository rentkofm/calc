import Foundation

struct Definition: Decodable, Hashable {
    let definition: String
    let example: String?
    let synonyms: [String]?
    let antonyms: [String]?
}

struct Meaning: Decodable, Hashable {
    let partOfSpeech: String
    let definitions: [Definition]
    let synonyms: [String]?
    let antonyms: [String]?
}

private struct Phonetic: Decodable {
    let text: String?
}

private struct RawEntry: Decodable {
    let word: String
    let phonetic: String?
    let phonetics: [Phonetic]?
    let meanings: [Meaning]
}

struct WordResult {
    let word: String
    let pronunciations: [String]
    let meanings: [Meaning]
    let synonyms: [String]
    let antonyms: [String]
    let related: [String]
}

enum LookupError: Error {
    case notFound
    case offline
}

/// Definitions and phonetics come from dictionaryapi.dev, related words from Datamuse.
enum DictionaryService {
    private struct DatamuseWord: Decodable { let word: String }

    static func lookup(_ raw: String) async throws -> WordResult {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        async let related = datamuse("ml", query, max: 24)
        async let synonyms = datamuse("rel_syn", query, max: 20)
        async let antonyms = datamuse("rel_ant", query, max: 12)

        let entries = try await entries(for: query)
        guard let first = entries.first else { throw LookupError.notFound }

        let meanings = entries.flatMap(\.meanings)
        let pronunciations = unique(entries.flatMap { entry in
            ([entry.phonetic] + (entry.phonetics ?? []).map(\.text)).compactMap { $0 }
        }.filter { !$0.isEmpty })

        let apiSyn = meanings.flatMap { ($0.synonyms ?? []) + $0.definitions.flatMap { $0.synonyms ?? [] } }
        let apiAnt = meanings.flatMap { ($0.antonyms ?? []) + $0.definitions.flatMap { $0.antonyms ?? [] } }

        let (moreSyn, moreAnt, moreRel) = await (synonyms, antonyms, related)
        let syn = unique(apiSyn + moreSyn).filter { $0 != query }
        let ant = unique(apiAnt + moreAnt).filter { $0 != query }
        let rel = unique(moreRel).filter { $0 != query && !syn.contains($0) && !ant.contains($0) }

        return WordResult(word: first.word,
                          pronunciations: Array(pronunciations.prefix(3)),
                          meanings: meanings,
                          synonyms: Array(syn.prefix(24)),
                          antonyms: Array(ant.prefix(16)),
                          related: Array(rel.prefix(20)))
    }

    static func suggestions(_ prefix: String) async -> [String] {
        let q = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return await datamuse("sug", q, max: 8, key: "s")
    }

    // MARK: - Networking

    private static func entries(for word: String) async throws -> [RawEntry] {
        guard let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(encoded)") else {
            throw LookupError.notFound
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if (response as? HTTPURLResponse)?.statusCode == 404 { throw LookupError.notFound }
            return try JSONDecoder().decode([RawEntry].self, from: data)
        } catch let error as LookupError {
            throw error
        } catch is DecodingError {
            throw LookupError.notFound
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw LookupError.offline
        }
    }

    private static func datamuse(_ rel: String, _ word: String, max: Int, key: String? = nil) async -> [String] {
        var comps = URLComponents(string: rel == "sug" ? "https://api.datamuse.com/sug" : "https://api.datamuse.com/words")!
        let param = key ?? (rel == "ml" ? "ml" : rel)
        comps.queryItems = [URLQueryItem(name: param, value: word), URLQueryItem(name: "max", value: String(max))]
        guard let url = comps.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let words = try? JSONDecoder().decode([DatamuseWord].self, from: data) else { return [] }
        return words.map(\.word)
    }

    private static func unique(_ words: [String]) -> [String] {
        var seen = Set<String>()
        return words.map { $0.lowercased() }.filter { seen.insert($0).inserted }
    }
}

/// Symbols seen in the pronunciations, with a familiar word to match each.
enum IPAKey {
    static let vowels: [(String, String)] = [
        ("iː", "see"), ("ɪ", "sit"), ("e / ɛ", "bed"), ("æ", "cat"), ("ɑː", "father"),
        ("ɒ / ɔ", "dog"), ("ʊ", "book"), ("uː", "blue"), ("ʌ", "cup"), ("ə", "about"),
        ("ɜː / ɝ", "bird"), ("eɪ", "day"), ("aɪ", "my"), ("ɔɪ", "boy"), ("aʊ", "now"),
        ("oʊ / əʊ", "go")
    ]
    static let consonants: [(String, String)] = [
        ("θ", "think"), ("ð", "this"), ("ʃ", "ship"), ("ʒ", "vision"), ("tʃ", "chip"),
        ("dʒ", "judge"), ("ŋ", "sing"), ("j", "yes"), ("ɹ / r", "red"), ("h", "hat")
    ]
    static let marks: [(String, String)] = [
        ("ˈ", "main stress: say this syllable strongest"),
        ("ˌ", "secondary stress"),
        ("ː", "long sound: hold it a little longer"),
        (".", "syllable break")
    ]
}
