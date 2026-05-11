import SwiftUI
import SwiftData

struct ReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(BadgeController.self) private var badgeController
    @Query(sort: \Article.pubDate, order: .reverse) private var articles: [Article]
    @State var selectedArticle: Article?

    init(selectedArticle: Article? = nil) {
        _selectedArticle = State(initialValue: selectedArticle)
    }

    var body: some View {
        NavigationSplitView {
            List(articles, selection: $selectedArticle) { article in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(article.isRead ? Color.clear : Color.accentColor)
                            .overlay(Circle().stroke(article.isRead ? Color.secondary : Color.clear, lineWidth: 1))
                            .frame(width: 5, height: 5)
                        Text(article.feed?.title ?? "")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(article.title)
                        .font(.caption)
                        .fontWeight(article.isRead ? .regular : .medium)
                        .foregroundStyle(article.isRead ? .secondary : .primary)
                        .lineLimit(2)
                }
                .padding(.vertical, 2)
                .tag(article)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 220, idealWidth: 240)
        } detail: {
            if let article = selectedArticle {
                articleDetail(article)
            } else {
                Text("Select an article")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: selectedArticle) { _, article in
            guard let article else { return }
            if !article.isRead {
                article.isRead = true
                try? modelContext.save()
                try? badgeController.update(context: modelContext)
            }
        }
    }

    @ViewBuilder
    private func articleDetail(_ article: Article) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button("← Prev") { selectAdjacent(offset: 1) }
                    .buttonStyle(.borderless)
                    .disabled(adjacentIndex(offset: 1) == nil)
                Button("Next →") { selectAdjacent(offset: -1) }
                    .buttonStyle(.borderless)
                    .disabled(adjacentIndex(offset: -1) == nil)
                Spacer()
                Button("✓ Mark Read") {
                    article.isRead = true
                    try? modelContext.save()
                    try? badgeController.update(context: modelContext)
                }
                .buttonStyle(.borderless)
                .disabled(article.isRead)
                Button("↗ Open in Browser") {
                    if let url = URL(string: article.link) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(article.feed?.title ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(article.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    ArticleContentView(html: article.summary) { url in
                        NSWorkspace.shared.open(url)
                    }
                    .frame(minHeight: 300)

                    HStack {
                        Text("Want the full article with images?")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("↗ Open in Browser") {
                            if let url = URL(string: article.link) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(24)
            }
        }
    }

    private func adjacentIndex(offset: Int) -> Int? {
        guard let current = selectedArticle,
              let idx = articles.firstIndex(of: current) else { return nil }
        let next = idx + offset
        return articles.indices.contains(next) ? next : nil
    }

    private func selectAdjacent(offset: Int) {
        guard let idx = adjacentIndex(offset: offset) else { return }
        selectedArticle = articles[idx]
    }
}
