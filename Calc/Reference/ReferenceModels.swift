import SwiftUI

/// One definition, symbol, law or term in the Reference tab.
struct RefEntry: Identifiable, Hashable {
    let id: String
    let term: String
    let text: String
    var formula: String? = nil
}

struct RefGroup: Identifiable {
    let title: String
    let entries: [RefEntry]
    var id: String { title }
    init(_ title: String, _ entries: [RefEntry]) { self.title = title; self.entries = entries }
}

struct RefSection: Identifiable {
    let id: String
    let title: String
    let icon: String
    let blurb: String
    let groups: [RefGroup]
    var count: Int { groups.reduce(0) { $0 + $1.entries.count } }
}

/// Short constructor used by the data files.
func rx(_ id: String, _ term: String, _ text: String, _ formula: String? = nil) -> RefEntry {
    RefEntry(id: id, term: term, text: text, formula: formula)
}

enum ReferenceStore {
    static let sections: [RefSection] = [
        symbolsSection, lawsSection, vocabularySection, constantsSection,
        fractalsSection, pendulumSection, toolsSection,
    ]

    /// Every entry by id, for the "i" buttons.
    static let index: [String: RefEntry] = {
        var d: [String: RefEntry] = [:]
        for s in sections { for g in s.groups { for e in g.entries { d[e.id] = e } } }
        return d
    }()

    static func entries(for keys: [String]) -> [RefEntry] { keys.compactMap { index[$0] } }

    /// Formula-sheet entries (from the Formulas page) as reference entries, for searching.
    static var formulaEntries: [RefEntry] {
        allFormulaEntries().enumerated().map { i, f in
            RefEntry(id: "formula.\(i)", term: f.name, text: f.note.isEmpty ? f.group : "\(f.group). \(f.note)", formula: f.formula)
        }
    }

    static func search(_ query: String) -> [(section: String, entry: RefEntry)] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        var out: [(String, RefEntry)] = []
        for s in sections {
            for g in s.groups {
                for e in g.entries where e.term.lowercased().contains(q) || e.text.lowercased().contains(q)
                    || (e.formula?.lowercased().contains(q) ?? false) {
                    out.append((s.title, e))
                }
            }
        }
        for e in formulaEntries where e.term.lowercased().contains(q) || e.text.lowercased().contains(q)
            || (e.formula?.lowercased().contains(q) ?? false) {
            out.append(("Formulas", e))
        }
        return out
    }
}
