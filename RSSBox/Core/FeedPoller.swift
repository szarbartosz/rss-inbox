import Foundation
import SwiftData
import Observation
import OSLog

private let logger = Logger(subsystem: "com.rssbox.RSSBox", category: "FeedPoller")

@Observable
@MainActor
final class FeedPoller {
    private var pollingTask: Task<Void, Never>?
    private let modelContainer: ModelContainer
    private let badgeController: BadgeController
    private let urlSession: URLSession

    init(modelContainer: ModelContainer, badgeController: BadgeController,
         urlSession: URLSession = .shared) {
        self.modelContainer = modelContainer
        self.badgeController = badgeController
        self.urlSession = urlSession
    }

    func start(intervalMinutes: Int) {
        stop()
        pollingTask = Task { [weak self] in
            await self?.pollAllFeeds()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(intervalMinutes * 60))
                guard !Task.isCancelled else { break }
                await self?.pollAllFeeds()
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func pollNow() {
        Task { await pollAllFeeds() }
    }

    func pollAllFeeds() async {
        let context = modelContainer.mainContext
        let feeds = (try? context.fetch(FetchDescriptor<Feed>())) ?? []
        for feed in feeds {
            await pollFeed(feed, context: context)
        }
        try? context.save()
        do {
            try badgeController.update(context: context)
        } catch {
            logger.error("Badge update after poll failed: \(error)")
        }
    }

    private func propagateToLiveWrappers(from feed: Feed) {
        let url = feed.url
        for other in Feed._liveWrappers.allObjects where other !== feed && other.url == url {
            other.lastFetched = feed.lastFetched
            other.fetchError = feed.fetchError
            if !feed.title.isEmpty { other.title = feed.title }
        }
    }

    private func pollFeed(_ feed: Feed, context: ModelContext) async {
        guard let url = URL(string: feed.url) else {
            feed.fetchError = "Invalid URL"
            propagateToLiveWrappers(from: feed)
            return
        }
        do {
            let (data, _) = try await urlSession.data(from: url)
            let parsed = try FeedParser().parse(data: data)

            if feed.title.isEmpty { feed.title = parsed.title }

            let retentionLimit = max(100, UserDefaults.standard.integer(forKey: "retentionLimit"))

            for item in parsed.items {
                let guid = item.guid
                let descriptor = FetchDescriptor<Article>(
                    predicate: #Predicate { $0.guid == guid }
                )
                let count = (try? context.fetchCount(descriptor)) ?? 0
                if count == 0 {
                    let article = Article(
                        guid: item.guid,
                        title: item.title,
                        summary: item.summary,
                        link: item.link,
                        pubDate: item.pubDate,
                        feed: feed
                    )
                    context.insert(article)
                }
            }

            let currentGuids = Set(parsed.items.map(\.guid))
            let allSorted = feed.articles.sorted { $0.pubDate > $1.pubDate }
            if allSorted.count > retentionLimit {
                let excess = allSorted.count - retentionLimit
                allSorted.suffix(excess)
                    .filter { $0.isRead && !currentGuids.contains($0.guid) }
                    .forEach { context.delete($0) }
            }

            feed.lastFetched = Date()
            feed.fetchError = nil
            propagateToLiveWrappers(from: feed)
        } catch {
            feed.fetchError = error.localizedDescription
            propagateToLiveWrappers(from: feed)
            logger.error("Poll failed for \(feed.url): \(error)")
        }
    }
}
