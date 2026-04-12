import Foundation
@testable import Rockxy
import Testing

// MARK: - TrafficDomainSnapshotTests

@MainActor
struct TrafficDomainSnapshotTests {
    @Test("update populates app entries with domains")
    func updatePopulatesAppEntries() {
        let snapshot = TrafficDomainSnapshot.shared
        let apps = [
            AppInfo(name: "TestApp", domains: ["api.test.com", "cdn.test.com"], requestCount: 5),
            AppInfo(name: "OtherApp", domains: ["other.com"], requestCount: 2),
        ]
        let domains = [
            DomainNode(id: "api.test.com", domain: "api.test.com", requestCount: 3, children: []),
            DomainNode(id: "cdn.test.com", domain: "cdn.test.com", requestCount: 2, children: []),
            DomainNode(id: "other.com", domain: "other.com", requestCount: 2, children: []),
        ]
        snapshot.update(appNodes: apps, domainTree: domains)

        #expect(snapshot.appEntries.count == 2)
        #expect(snapshot.domains.count == 3)
    }

    @Test("domains(forApp:) returns observed domains for a known app")
    func domainsForKnownApp() {
        let snapshot = TrafficDomainSnapshot.shared
        let apps = [
            AppInfo(name: "Browser", domains: ["example.com", "cdn.example.com"], requestCount: 10),
        ]
        snapshot.update(appNodes: apps, domainTree: [])

        let result = snapshot.domains(forApp: "Browser")
        #expect(result.count == 2)
        #expect(result.contains("example.com"))
        #expect(result.contains("cdn.example.com"))
    }

    @Test("domains(forApp:) returns empty for unknown app")
    func domainsForUnknownApp() {
        let snapshot = TrafficDomainSnapshot.shared
        snapshot.update(appNodes: [], domainTree: [])

        let result = snapshot.domains(forApp: "NonexistentApp")
        #expect(result.isEmpty)
    }

    @Test("selecting a domain adds it directly without manual entry")
    func domainSelectionAddsDirect() {
        let snapshot = TrafficDomainSnapshot.shared
        let domains = [
            DomainNode(id: "api.test.com", domain: "api.test.com", requestCount: 1, children: []),
        ]
        snapshot.update(appNodes: [], domainTree: domains)

        #expect(snapshot.domains.contains("api.test.com"))
    }

    @Test("selecting an app resolves its real observed domains")
    func appSelectionUsesRealDomains() {
        let snapshot = TrafficDomainSnapshot.shared
        let apps = [
            AppInfo(name: "MyApp", domains: ["real-api.myapp.com", "analytics.myapp.com"], requestCount: 8),
        ]
        snapshot.update(appNodes: apps, domainTree: [])

        let resolved = snapshot.domains(forApp: "MyApp")
        #expect(resolved == ["real-api.myapp.com", "analytics.myapp.com"])
        #expect(!resolved.contains { $0.hasPrefix("*.") })
    }

    @Test("app with no observed domains returns empty — no guessed wildcards")
    func appWithNoDomains() {
        let snapshot = TrafficDomainSnapshot.shared
        let apps = [
            AppInfo(name: "SilentApp", domains: [], requestCount: 0),
        ]
        snapshot.update(appNodes: apps, domainTree: [])

        let resolved = snapshot.domains(forApp: "SilentApp")
        #expect(resolved.isEmpty)
    }
}
