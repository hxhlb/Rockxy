import Foundation

// MARK: - DeveloperSetupRoute

struct DeveloperSetupRoute: Equatable {
    let targetID: SetupTarget.ID
    let tab: SetupDetailTab
}

// MARK: - DeveloperSetupRouteStore

@MainActor @Observable
final class DeveloperSetupRouteStore {
    static let shared = DeveloperSetupRouteStore()

    var pendingRoute: DeveloperSetupRoute?

    func request(targetID: SetupTarget.ID, tab: SetupDetailTab = .setup) {
        pendingRoute = DeveloperSetupRoute(targetID: targetID, tab: tab)
    }

    func consumePendingRoute() -> DeveloperSetupRoute? {
        defer { pendingRoute = nil }
        return pendingRoute
    }

    private init() {}
}
