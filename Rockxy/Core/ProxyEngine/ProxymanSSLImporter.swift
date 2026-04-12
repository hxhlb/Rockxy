import Foundation
import os

// MARK: - ProxymanSSLImporter

/// Imports SSL proxy settings from exported JSON format.
/// Supports structured format with include/exclude keys or a flat string array.
enum ProxymanSSLImporter {
    // MARK: Internal

    enum ImportError: LocalizedError {
        case invalidFormat

        // MARK: Internal

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                String(localized: "The file is not a valid SSL settings export.")
            }
        }
    }

    static func importRules(from data: Data) throws -> [SSLProxyingRule] {
        if let structured = try? JSONDecoder().decode(StructuredExport.self, from: data) {
            return buildRules(from: structured)
        }

        if let flat = try? JSONDecoder().decode([String].self, from: data) {
            return deduplicateAsInclude(flat)
        }

        throw ImportError.invalidFormat
    }

    // MARK: Private

    private struct StructuredExport: Codable {
        var includeDomains: [String]?
        var excludeDomains: [String]?
    }

    private static let logger = Logger(
        subsystem: RockxyIdentity.current.logSubsystem,
        category: "ProxymanSSLImporter"
    )

    private static func buildRules(from export: StructuredExport) -> [SSLProxyingRule] {
        var seen = Set<String>()
        var rules: [SSLProxyingRule] = []

        for domain in export.includeDomains ?? [] {
            let trimmed = domain.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                continue
            }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else {
                continue
            }
            seen.insert(key)
            rules.append(SSLProxyingRule(domain: trimmed, listType: .include))
        }

        for domain in export.excludeDomains ?? [] {
            let trimmed = domain.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                continue
            }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else {
                continue
            }
            seen.insert(key)
            rules.append(SSLProxyingRule(domain: trimmed, listType: .exclude))
        }

        logger.info("Imported \(rules.count) rules from structured format")
        return rules
    }

    private static func deduplicateAsInclude(_ domains: [String]) -> [SSLProxyingRule] {
        var seen = Set<String>()
        var rules: [SSLProxyingRule] = []

        for domain in domains {
            let trimmed = domain.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                continue
            }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else {
                continue
            }
            seen.insert(key)
            rules.append(SSLProxyingRule(domain: trimmed, listType: .include))
        }

        logger.info("Imported \(rules.count) rules from flat array format")
        return rules
    }
}
