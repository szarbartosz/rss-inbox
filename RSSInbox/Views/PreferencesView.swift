import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import ServiceManagement

struct PreferencesView: View {
    var body: some View {
        TabView {
            FeedsPreferencesView()
                .tabItem { Label("Feeds", systemImage: "list.bullet.rectangle") }
            GeneralPreferencesView()
                .tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 520, height: 380)
    }
}

struct FeedsPreferencesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(FeedPoller.self) private var feedPoller
    @Query(sort: \Feed.title) private var feeds: [Feed]
    @State private var newURL = ""
    @State private var addError: String?
    @State private var isAdding = false
    @State private var selectedFeedID: UUID?
    @State private var showImportPanel = false
    @State private var importSummary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Table(feeds, selection: $selectedFeedID) {
                TableColumn("Title", value: \.title)
                TableColumn("URL", value: \.url)
                TableColumn("Last Fetched") { feed in
                    Text(feed.lastFetched.map { $0.formatted(.relative(presentation: .named)) } ?? "Never")
                        .font(.caption)
                }
                TableColumn("Status") { feed in
                    if let err = feed.fetchError {
                        Text("⚠ \(err)")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    } else if feed.lastFetched != nil {
                        Text("✓").foregroundStyle(.green)
                    } else {
                        Text("—").foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Button(role: .destructive) {
                    guard let id = selectedFeedID,
                          let feed = feeds.first(where: { $0.id == id }) else { return }
                    modelContext.delete(feed)
                    try? modelContext.save()
                    selectedFeedID = nil
                } label: {
                    Label("Remove", systemImage: "minus")
                }
                .disabled(selectedFeedID == nil)

                Spacer()

                Button("Import OPML") { showImportPanel = true }
                Button("Export OPML") { exportOPML() }
            }

            Divider()

            HStack {
                TextField("https://example.com/feed.rss", text: $newURL)
                    .textFieldStyle(.roundedBorder)
                Button(isAdding ? "Adding…" : "Add") {
                    Task { await addFeed() }
                }
                .disabled(newURL.isEmpty || isAdding)
            }

            if let error = addError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let summary = importSummary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .fileImporter(
            isPresented: $showImportPanel,
            allowedContentTypes: [UTType(filenameExtension: "opml")!, .xml]
        ) { result in
            Task { await importOPML(result: result) }
        }
    }

    private func addFeed() async {
        isAdding = true
        addError = nil
        defer { isAdding = false }

        guard let url = URL(string: newURL), url.scheme?.hasPrefix("http") == true else {
            addError = "Please enter a valid http(s) URL"
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let parsed = try FeedParser().parse(data: data)
            let feed = Feed(url: newURL, title: parsed.title.isEmpty ? newURL : parsed.title)
            modelContext.insert(feed)
            try modelContext.save()
            newURL = ""
            feedPoller.pollNow()
        } catch {
            addError = "Not a valid RSS/Atom feed"
        }
    }

    private func importOPML(result: Result<URL, Error>) async {
        do {
            let fileURL = try result.get()
            guard fileURL.startAccessingSecurityScopedResource() else { return }
            defer { fileURL.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: fileURL)
            let opmlFeeds = try OPMLParser().parse(data: data)

            let existingURLs = Set(feeds.map(\.url))
            var added = 0
            var skipped = 0
            for opmlFeed in opmlFeeds {
                if existingURLs.contains(opmlFeed.url) {
                    skipped += 1
                } else {
                    modelContext.insert(Feed(url: opmlFeed.url, title: opmlFeed.title))
                    added += 1
                }
            }
            try modelContext.save()
            importSummary = "\(added) feed\(added == 1 ? "" : "s") added, \(skipped) duplicate\(skipped == 1 ? "" : "s") skipped"
            feedPoller.pollNow()
        } catch {
            importSummary = "Failed to import: \(error.localizedDescription)"
        }
    }

    private func exportOPML() {
        let opmlFeeds = feeds.map { OPMLFeed(title: $0.title, url: $0.url) }
        let data = OPMLParser().generate(feeds: opmlFeeds)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "opml")!]
        panel.nameFieldStringValue = "rss-box-feeds.opml"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }
}

struct GeneralPreferencesView: View {
    @Environment(FeedPoller.self) private var feedPoller
    @AppStorage("pollIntervalMinutes") private var pollIntervalMinutes = 15
    @AppStorage("retentionLimit") private var retentionLimit = 100
    @State private var launchAtLogin = false

    private let intervalOptions = [5, 15, 30, 60]
    private let retentionOptions = [100, 250, 500]

    var body: some View {
        Form {
            Section("Polling") {
                Picker("Check for updates every", selection: $pollIntervalMinutes) {
                    ForEach(intervalOptions, id: \.self) { mins in
                        Text("\(mins) minutes").tag(mins)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: pollIntervalMinutes) { _, newValue in
                    feedPoller.stop()
                    feedPoller.start(intervalMinutes: newValue)
                }
            }

            Section("Storage") {
                Picker("Keep per feed", selection: $retentionLimit) {
                    ForEach(retentionOptions, id: \.self) { n in
                        Text("Last \(n) articles").tag(n)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("System") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
