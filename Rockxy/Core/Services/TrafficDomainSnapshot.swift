import Foundation

// MARK: - TrafficDomainSnapshot

/// Lightweight read-only snapshot of observed apps and domains from live traffic.
/// Updated by `MainContentCoordinator` on each batch; read by secondary windows
/// (like the SSL Proxying List) that need traffic context without a coordinator reference.
@MainActor @Observable
final class TrafficDomainSnapshot {
    // MARK: Lifecycle

    private init() {}

    // MARK: Internal

    static let shared = TrafficDomainSnapshot()

    private(set) var appNames: [String] = []
    private(set) var domains: [String] = []

    func update(appNodes: [AppInfo], domainTree: [DomainNode]) {
        appNames = appNodes.map(\.name).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        domains = domainTree.map(\.domain).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }
}
