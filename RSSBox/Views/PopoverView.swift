import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.rssbox.RSSBox", category: "PopoverView")

struct PopoverView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openSettings) private var openSettings
    @Environment(BadgeController.self) private var badgeController
    @Environment(FeedPoller.self) private var feedPoller
    @Query(sort: \Feed.title) private var feeds: [Feed]
    @Query(sort: \Article.pubDate, order: .reverse) private var allArticles: [Article]
    @State private var selectedFeedID: UUID? = nil

    private var filteredArticles: [Article] {
        guard let id = selectedFeedID else { return allArticles }
        return allArticles.filter { $0.feed?.id == id }
    }

    private var lastUpdated: String {
        guard let date = feeds.compactMap(\.lastFetched).max() else { return "Never" }
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return "Just now" }
        if diff < 3600 { return "\(diff / 60)m ago" }
        return "\(diff / 3600)h ago"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("RSS Inbox")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Button { feedPoller.pollNow() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .font(.caption)
                Button {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Image(systemName: "gear")
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            // Feed filter tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    feedTab(id: nil, label: "All",
                            count: allArticles.filter { !$0.isRead }.count)
                    ForEach(feeds) { feed in
                        let unread = feed.articles.filter { !$0.isRead }.count
                        feedTab(id: feed.id, label: feed.title, count: unread,
                                hasError: feed.fetchError != nil)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(.bar)

            Divider()

            // Article list
            if filteredArticles.isEmpty {
                Spacer()
                Text("No articles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredArticles) { article in
                            ArticleRowView(article: article) {
                                markRead(article)
                                ReaderWindowController.shared.show(article: article)
                            }
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                Text("Updated \(lastUpdated)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Mark all read") { markAllRead() }
                    .buttonStyle(DimOnPressButtonStyle())
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .frame(width: 320, height: 480)
    }

    @ViewBuilder
    private func feedTab(id: UUID?, label: String, count: Int, hasError: Bool = false) -> some View {
        let isSelected = selectedFeedID == id
        Button {
            selectedFeedID = id
        } label: {
            HStack(spacing: 3) {
                if hasError { Text("⚠").font(.caption2) }
                Text(count > 0 ? "\(label) (\(count))" : label)
                    .font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.borderless)
    }

    private func markRead(_ article: Article) {
        article.isRead = true
        try? modelContext.save()
        do {
            try badgeController.update(context: modelContext)
        } catch {
            logger.error("Badge update failed: \(error)")
        }
    }

    private func markAllRead() {
        filteredArticles.forEach { $0.isRead = true }
        try? modelContext.save()
        do {
            try badgeController.update(context: modelContext)
        } catch {
            logger.error("Badge update failed: \(error)")
        }
    }
}

private struct DimOnPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.4 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
