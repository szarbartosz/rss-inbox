# RSSBox — Project Context

Native macOS 15 menu bar RSS reader built with SwiftUI + SwiftData.

## Task 8: FeedPoller — STATUS: IN PROGRESS (3 tests failing)

### What was done
- Created `RSSBoxTests/FeedPollerIntegrationTests.swift` (integration tests with MockURLProtocol)
- Replaced `RSSBox/Core/FeedPoller.swift` stub with full implementation
- Ran `xcodegen generate` to sync project

### Current test results (22 total, 3 failing)
```
PASSING (19): OPMLParser (6), FeedParser (6), Models (2), BadgeController (4), pollDeduplicatesOnRepeat
FAILING (3):
  - pollInsertsNewArticles   — feed.lastFetched == nil (expected != nil)
  - pollSetsErrorOnNetworkFailure — feed.fetchError == nil (expected != nil)
  - pollUpdatesFeedTitle     — feed.title == "" (expected "Test RSS Feed")
```

### Root cause of failures
`pollAllFeeds()` creates a fresh `ModelContext(modelContainer)` internally. It fetches
Feed objects into that NEW context, modifies them (sets lastFetched, fetchError, title),
and saves. The test holds a reference to the Feed object from its OWN context
(`ModelContext(container)`). After `pollAllFeeds()` returns, the test's feed object
is stale — the changes exist in the store but the in-memory object isn't refreshed.

`pollDeduplicatesOnRepeat` passes because it re-fetches articles with
`context.fetch(FetchDescriptor<Article>())` — a fresh fetch from the store.
The failing tests check properties directly on the original `feed` variable.

### Fix needed
The solution must make the test's `feed` object reflect changes after `pollAllFeeds()`.
Options (without modifying tests):

**Option A (preferred):** Store a `mainContext` on the poller (created once at init
from the container), and use THAT context for all operations. Since the test also
creates `ModelContext(container)`, both would be separate contexts — BUT SwiftData
should merge changes between them automatically when they share the same
`ModelContainer`. The issue may be that SwiftData in-memory stores don't auto-merge
without an explicit `context.processPendingChanges()` or notification handling.

**Option B:** After `try? context.save()` in `pollAllFeeds()`, post a
`NSManagedObjectContext.didSaveObjectsNotification` merge — but SwiftData may handle
this differently from CoreData.

**Option C:** Check if `ModelContext` has a `mergeChanges` or `refreshAllObjects()`
equivalent in SwiftData. SwiftData's `ModelContext` has no public `refresh` API.

**Option D (likely correct):** The test's `feed` IS the same persistent object if
both contexts pull from the same in-memory store. The SwiftData `@Model` objects
are Observable reference types backed by NSManagedObject. When context B saves,
context A's model objects should observe the change via `@Observable` machinery.
The issue might be that the save in the poller's context needs to happen BEFORE
the test checks the property — check if `await poller.pollAllFeeds()` properly
awaits all async work including the save.

**Option E (simplest if store merges):** Just verify the implementation is correct
and that an explicit `context.processPendingChanges()` on the poller's context
after save triggers the merge. SwiftData may need `autosaveEnabled = true` or
a `NotificationCenter` listener for `NSPersistentStoreRemoteChange`.

### Files to look at
- `/Users/szarbartosz/Developer/rss-box/RSSBox/Core/FeedPoller.swift` — current implementation
- `/Users/szarbartosz/Developer/rss-box/RSSBoxTests/FeedPollerIntegrationTests.swift` — tests (DO NOT MODIFY)
- `/Users/szarbartosz/Developer/rss-box/RSSBox/Models/Feed.swift` — Feed model
- `/Users/szarbartosz/Developer/rss-box/RSSBox/Models/Article.swift` — Article model
- `/Users/szarbartosz/Developer/rss-box/project.yml` — XcodeGen config

### Commands to run tests
```bash
cd /Users/szarbartosz/Developer/rss-box
xcodegen generate
xcodebuild test -scheme RSSBox -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "(passed|failed|error:)"
```

### Git commit (to do after all 22 pass)
```bash
git add RSSBox/Core/FeedPoller.swift RSSBoxTests/FeedPollerIntegrationTests.swift RSSBox.xcodeproj/project.pbxproj
git commit -m "feat: implement FeedPoller with deduplication and retention pruning"
```

### Key design facts
- `FeedPoller` is `@Observable @MainActor`
- `BadgeController.update(context:)` is `@MainActor` and throws
- `FeedParser().parse(data:)` returns `ParsedFeed` with `.title` and `.items`
- `Article` init: `(guid:title:summary:link:pubDate:feed:)`
- `Feed.articles` is `[Article]` (cascade delete relationship)
- `retentionLimit` defaults to `max(100, UserDefaults.standard.integer(forKey: "retentionLimit"))`
- rss2.xml fixture: title="Test RSS Feed", 2 items
- Target: 22 tests all passing
