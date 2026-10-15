import SwiftUI

struct HistoryView: View {
    @Environment(HistoryStore.self) private var history
    @State private var query = ""
    @State private var confirmClear = false

    private var filtered: [Transcript] {
        query.isEmpty ? history.items : history.items.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if history.items.isEmpty {
                    ContentUnavailableView("No Transcripts", systemImage: "clock",
                                           description: Text("Finished sessions are saved here."))
                } else {
                    List {
                        ForEach(filtered) { item in
                            NavigationLink {
                                TranscriptDetail(item: item)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.footnote).foregroundStyle(.secondary)
                                    Text(item.text).lineLimit(3)
                                }
                            }
                            .listRowBackground(Rectangle().fill(.ultraThinMaterial))
                        }
                        .onDelete { offsets in history.delete(ids: Set(offsets.map { filtered[$0].id })) }
                    }
                    .scrollContentBackground(.hidden)
                    .searchable(text: $query)
                }
            }
            .background(AmbientBackground())
            .navigationTitle("History")
            .toolbar {
                if !history.items.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear", role: .destructive) { confirmClear = true }
                    }
                }
            }
            .confirmationDialog("Delete all saved transcripts?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Delete All", role: .destructive) { history.clear() }
            }
        }
    }
}

struct TranscriptDetail: View {
    @Environment(AppSettings.self) private var settings
    @Environment(HistoryStore.self) private var history
    @Environment(\.dismiss) private var dismiss
    let item: Transcript

    var body: some View {
        ScrollView {
            Text(item.text)
                .font(.system(size: settings.textSize, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .glassEffect(.regular, in: .rect(cornerRadius: 28))
                .padding()
                .textSelection(.enabled)
        }
        .background(AmbientBackground())
        .navigationTitle(item.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = item.text }
                ShareLink(item: item.text)
                Button("Delete", systemImage: "trash", role: .destructive) {
                    history.delete(ids: [item.id]); dismiss()
                }
            }
        }
    }
}
