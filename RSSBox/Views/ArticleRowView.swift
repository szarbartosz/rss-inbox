import SwiftUI

struct ArticleRowView: View {
    let article: Article
    let onRead: () -> Void

    private var ageString: String {
        let diff = Date().timeIntervalSince(article.pubDate)
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(article.isRead ? Color.clear : Color.accentColor)
                        .overlay(Circle().stroke(article.isRead ? Color.secondary : Color.clear, lineWidth: 1))
                        .frame(width: 6, height: 6)
                        .padding(.top, 1)
                    Text("\(article.feed?.title ?? "") · \(ageString)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(article.title)
                    .font(.caption)
                    .fontWeight(article.isRead ? .regular : .medium)
                    .foregroundStyle(article.isRead ? .secondary : .primary)
                    .lineLimit(2)
                Text(article.summary)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
            Spacer()
            Button("Read") { onRead() }
                .buttonStyle(.borderless)
                .font(.caption2)
                .foregroundStyle(Color.accentColor)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .opacity(article.isRead ? 0.6 : 1.0)
        .background(Color.clear)
    }
}
