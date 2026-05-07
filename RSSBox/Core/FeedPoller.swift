import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class FeedPoller {
    private let modelContainer: ModelContainer
    private let badgeController: BadgeController

    init(modelContainer: ModelContainer, badgeController: BadgeController) {
        self.modelContainer = modelContainer
        self.badgeController = badgeController
    }

    func start(intervalMinutes: Int) {}
    func stop() {}
    func pollNow() {}
}
