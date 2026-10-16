import SwiftUI

/// The Reference tab: formulas, a compendium of math notation, laws and vocabulary, and definitions
/// for every fractal, pendulum and Extras tool.
struct ReferenceView: View {
    @State private var query = ""
    @Environment(\.appAccent) private var accent

    var body: some View {
        NavigationStack {
            ScrollView {
                if query.trimmingCharacters(in: .whitespaces).isEmpty { home } else { results }
            }
            .background { AppBackground() }
            .navigationTitle("Reference")
            .searchable(text: $query, prompt: "Search symbols, theorems, terms…")
            .scrollDismissesKeyboard(.interactively)
            .navigationDestination(for: String.self) { id in
                if id == "formulas" {
                    FormulasView()
                        .background { AppBackground() }
                        .navigationTitle("Formulas")
                        .navigationBarTitleDisplayMode(.inline)
                } else if let section = ReferenceStore.sections.first(where: { $0.id == id }) {
                    ReferenceSectionView(section: section)
                }
            }
        }
    }

    private var total: Int { ReferenceStore.sections.reduce(0) { $0 + $1.count } }

    private var home: some View {
        VStack(spacing: 14) {
            NavigationLink(value: "formulas") {
                card(icon: "function", title: "Formulas", detail: "Geometry, algebra, trig, calculus, physics, finance and more")
            }
            .buttonStyle(.plain)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(ReferenceStore.sections) { section in
                    NavigationLink(value: section.id) {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: section.icon).font(.title2).foregroundStyle(accent)
                            Text(section.title).font(.headline).multilineTextAlignment(.leading)
                            Text("\(section.count) entries").font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                        .padding(14)
                        .glassEffect(.regular, in: .rect(cornerRadius: 22))
                        .contentShape(.rect(cornerRadius: 22))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("\(total) entries across \(ReferenceStore.sections.count) sections, plus the formula sheet. Every fractal, pendulum and Extras tool has an ⓘ button that opens its entry here.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
    }

    private var results: some View {
        let hits = ReferenceStore.search(query)
        return LazyVStack(alignment: .leading, spacing: 10) {
            Text("\(hits.count) result\(hits.count == 1 ? "" : "s")").font(.footnote).foregroundStyle(.secondary)
            ForEach(Array(hits.prefix(300).enumerated()), id: \.offset) { _, hit in
                RefCard(entry: hit.entry, tag: hit.section)
            }
            if hits.count > 300 { Text("Showing the first 300. Refine your search.").font(.footnote).foregroundStyle(.secondary) }
        }
        .padding(16)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
    }

    private func card(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(accent).frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .contentShape(.rect(cornerRadius: 22))
    }
}

/// One section of the compendium, with its groups.
struct ReferenceSectionView: View {
    let section: RefSection
    @State private var query = ""
    @State private var selected: String?
    @Environment(\.appAccent) private var accent

    private var groups: [RefGroup] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return section.groups.compactMap { g in
            guard selected == nil || selected == g.title else { return nil }
            guard !q.isEmpty else { return g }
            let hits = g.entries.compactMap { e in e.matchRank(q).map { (rank: $0, entry: e) } }
                .enumerated().sorted { $0.element.rank != $1.element.rank ? $0.element.rank < $1.element.rank : $0.offset < $1.offset }
                .map { $0.element.entry }
            return hits.isEmpty ? nil : RefGroup(g.title, hits)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(section.blurb).font(.subheadline).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    GlassEffectContainer(spacing: 8) {
                        HStack(spacing: 8) {
                            chip("All", isSelected: selected == nil) { selected = nil }
                            ForEach(section.groups) { g in
                                chip(g.title, isSelected: selected == g.title) { selected = g.title }
                            }
                        }
                    }
                }
                LazyVStack(alignment: .leading, spacing: 10, pinnedViews: []) {
                    ForEach(groups) { g in
                        Text(g.title).font(.title3.weight(.semibold)).padding(.top, 8)
                        ForEach(g.entries) { RefCard(entry: $0) }
                    }
                    if groups.isEmpty { Text("Nothing matches.").foregroundStyle(.secondary) }
                }
            }
            .padding(16)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background { AppBackground() }
        .navigationTitle(section.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search \(section.title.lowercased())")
        .scrollDismissesKeyboard(.interactively)
    }

    private func chip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
        }
        .buttonStyle(.plain)
        .glassEffect(isSelected ? .regular.tint(accent).interactive() : .regular.interactive(), in: Capsule())
    }
}

/// A single entry.
struct RefCard: View {
    let entry: RefEntry
    var tag: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.term).font(.headline)
                Spacer(minLength: 8)
                if let tag { Text(tag).font(.caption2.weight(.semibold)).foregroundStyle(.secondary) }
            }
            Text(entry.text)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            if let formula = entry.formula {
                Text(formula)
                    .font(.system(.callout, design: .rounded).weight(.medium))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.secondary.opacity(0.12), in: .rect(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        // A plain material rather than glass: a section can hold hundreds of cards and glass is costly per card.
        .background(.thinMaterial, in: .rect(cornerRadius: 20))
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = [entry.term, entry.text, entry.formula].compactMap { $0 }.joined(separator: "\n")
            }
        }
    }
}

/// The sheet opened by the ⓘ buttons.
struct ReferenceInfoSheet: View {
    let keys: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                let entries = ReferenceStore.entries(for: keys)
                VStack(spacing: 10) {
                    if entries.isEmpty {
                        Text("No definition has been written for this yet.").foregroundStyle(.secondary).padding()
                    }
                    ForEach(entries) { RefCard(entry: $0) }
                    Text("Find more in the Reference tab.").font(.footnote).foregroundStyle(.secondary).padding(.top, 6)
                }
                .padding(16)
            }
            .background { AppBackground() }
            .navigationTitle("About this")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
