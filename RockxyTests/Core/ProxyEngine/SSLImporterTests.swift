import Foundation
@testable import Rockxy
import Testing

// MARK: - CharlesSSLImporterTests

@MainActor
struct CharlesSSLImporterTests {
    @Test("imports valid Charles plist with locations")
    func importValidPlist() throws {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>location</key>
            <array>
                <dict>
                    <key>host</key>
                    <string>*.example.com</string>
                    <key>port</key>
                    <integer>443</integer>
                </dict>
                <dict>
                    <key>host</key>
                    <string>api.stripe.com</string>
                    <key>port</key>
                    <integer>443</integer>
                </dict>
            </array>
        </dict>
        </plist>
        """
        let data = Data(plist.utf8)
        let rules = try CharlesSSLImporter.importRules(from: data)
        #expect(rules.count == 2)
        #expect(rules[0].domain == "*.example.com")
        #expect(rules[1].domain == "api.stripe.com")
        #expect(rules.allSatisfy { $0.listType == .include })
    }

    @Test("converts bare * to *.*")
    func convertsBareWildcard() throws {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>location</key>
            <array>
                <dict><key>host</key><string>*</string><key>port</key><integer>443</integer></dict>
            </array>
        </dict>
        </plist>
        """
        let rules = try CharlesSSLImporter.importRules(from: Data(plist.utf8))
        #expect(rules[0].domain == "*.*")
    }

    @Test("deduplicates case-insensitively")
    func deduplicates() throws {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>location</key>
            <array>
                <dict><key>host</key><string>Example.com</string></dict>
                <dict><key>host</key><string>example.com</string></dict>
            </array>
        </dict>
        </plist>
        """
        let rules = try CharlesSSLImporter.importRules(from: Data(plist.utf8))
        #expect(rules.count == 1)
    }

    @Test("throws invalidFormat for non-plist data")
    func invalidFormat() {
        let data = Data("not a plist".utf8)
        #expect(throws: CharlesSSLImporter.ImportError.self) {
            try CharlesSSLImporter.importRules(from: data)
        }
    }

    @Test("throws noLocationsFound for empty locations")
    func emptyLocations() {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>location</key>
            <array></array>
        </dict>
        </plist>
        """
        #expect(throws: CharlesSSLImporter.ImportError.self) {
            try CharlesSSLImporter.importRules(from: Data(plist.utf8))
        }
    }
}

// MARK: - ProxymanSSLImporterTests

@MainActor
struct ProxymanSSLImporterTests {
    @Test("imports structured format with include and exclude")
    func importStructured() throws {
        let json = """
        {"includeDomains":["*.api.com","app.com"],"excludeDomains":["*.internal.com"]}
        """
        let rules = try ProxymanSSLImporter.importRules(from: Data(json.utf8))
        #expect(rules.count == 3)
        let include = rules.filter { $0.listType == .include }
        let exclude = rules.filter { $0.listType == .exclude }
        #expect(include.count == 2)
        #expect(exclude.count == 1)
    }

    @Test("imports flat array format")
    func importFlatArray() throws {
        let json = """
        ["*.example.com","api.stripe.com"]
        """
        let rules = try ProxymanSSLImporter.importRules(from: Data(json.utf8))
        #expect(rules.count == 2)
        #expect(rules.allSatisfy { $0.listType == .include })
    }

    @Test("deduplicates domains")
    func deduplicates() throws {
        let json = """
        ["example.com","Example.COM","example.com"]
        """
        let rules = try ProxymanSSLImporter.importRules(from: Data(json.utf8))
        #expect(rules.count == 1)
    }

    @Test("throws invalidFormat for invalid JSON")
    func invalidFormat() {
        #expect(throws: ProxymanSSLImporter.ImportError.self) {
            try ProxymanSSLImporter.importRules(from: Data("bad".utf8))
        }
    }
}

// MARK: - HTTPToolkitImporterTests

@MainActor
struct HTTPToolkitImporterTests {
    @Test("imports dictionary with known keys")
    func importDictionary() throws {
        let json = """
        {"whitelistedHosts":["a.com"],"interceptedHosts":["b.com"],"hosts":["c.com"]}
        """
        let rules = try HTTPToolkitImporter.importRules(from: Data(json.utf8))
        #expect(rules.count == 3)
        #expect(rules.allSatisfy { $0.listType == .include })
    }

    @Test("imports flat array")
    func importFlatArray() throws {
        let json = """
        ["x.com","y.com"]
        """
        let rules = try HTTPToolkitImporter.importRules(from: Data(json.utf8))
        #expect(rules.count == 2)
    }

    @Test("deduplicates across keys")
    func deduplicates() throws {
        let json = """
        {"whitelistedHosts":["dup.com"],"hosts":["DUP.com"]}
        """
        let rules = try HTTPToolkitImporter.importRules(from: Data(json.utf8))
        #expect(rules.count == 1)
    }

    @Test("throws invalidFormat for non-JSON data")
    func invalidFormat() {
        #expect(throws: HTTPToolkitImporter.ImportError.self) {
            try HTTPToolkitImporter.importRules(from: Data("bad".utf8))
        }
    }
}
