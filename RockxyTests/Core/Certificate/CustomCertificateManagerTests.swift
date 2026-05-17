import Crypto
import Foundation
import SwiftASN1
@testable import Rockxy
import Testing
import X509

// MARK: - MemorySecureDataStore

private final class MemorySecureDataStore: SecureDataStore, @unchecked Sendable {
    func save(_ data: Data, account: String) throws {
        lock.withLock {
            values[account] = data
        }
    }

    func load(account: String) throws -> Data? {
        lock.withLock { values[account] }
    }

    func delete(account: String) throws {
        _ = lock.withLock {
            values.removeValue(forKey: account)
        }
    }

    private let lock = NSLock()
    private var values: [String: Data] = [:]
}

// MARK: - CustomCertificateManagerTests

struct CustomCertificateManagerTests {
    @Test("imports custom root certificate and exposes it as active issuer")
    func importsCustomRootIssuer() throws {
        let manager = makeManager()
        let root = try RootCAGenerator.generate()

        _ = try manager.importRoot(
            displayName: "Custom Root",
            certificatePEM: try pem(root.certificate),
            privateKeyPEM: root.privateKey.pemRepresentation
        )

        let issuer = try #require(try manager.activeRootIssuer())
        #expect(issuer.certificate.subject == root.certificate.subject)
        #expect(issuer.privateKey.publicKey.subjectPublicKeyInfoBytes == root.certificate.publicKey.subjectPublicKeyInfoBytes)
    }

    @Test("matches exact and wildcard server certificate hosts")
    func matchesServerHostPatterns() throws {
        let manager = makeManager()
        let identity = try makeLeafIdentity(host: "api.example.com")

        try manager.importServerIdentity(
            hostPattern: "*.example.com",
            displayName: "Pinned Server",
            certificatePEM: identity.certificatePEM,
            privateKeyPEM: identity.privateKeyPEM
        )

        #expect(manager.serverIdentity(for: "api.example.com") != nil)
        #expect(manager.serverIdentity(for: "example.com") == nil)
        #expect(manager.serverIdentity(for: "api.example.net") == nil)
    }

    @Test("matches client certificates only for configured hosts")
    func matchesClientHostPatterns() throws {
        let manager = makeManager()
        let identity = try makeLeafIdentity(host: "mtls.example.com")

        try manager.importClientIdentity(
            hostPattern: "mtls.example.com",
            displayName: "mTLS Client",
            certificatePEM: identity.certificatePEM,
            privateKeyPEM: identity.privateKeyPEM
        )

        #expect(manager.clientIdentity(for: "mtls.example.com") != nil)
        #expect(manager.clientIdentity(for: "www.example.com") == nil)
    }

    @Test("rejects invalid certificate key pairs")
    func rejectsInvalidCertificateKeyPairs() throws {
        let manager = makeManager()
        let first = try makeLeafIdentity(host: "one.example.com")
        let second = try makeLeafIdentity(host: "two.example.com")

        #expect(throws: CustomCertificateError.invalidCertificateKeyPair) {
            try manager.importServerIdentity(
                hostPattern: "one.example.com",
                displayName: "Invalid",
                certificatePEM: first.certificatePEM,
                privateKeyPEM: second.privateKeyPEM
            )
        }
    }

    @Test("delete and revert remove custom certificate behavior")
    func deleteAndRevert() throws {
        let manager = makeManager()
        let identity = try makeLeafIdentity(host: "delete.example.com")
        let entry = try manager.importServerIdentity(
            hostPattern: "delete.example.com",
            displayName: "Delete Me",
            certificatePEM: identity.certificatePEM,
            privateKeyPEM: identity.privateKeyPEM
        )

        #expect(manager.serverIdentity(for: "delete.example.com") != nil)
        try manager.delete(id: entry.id)
        #expect(manager.serverIdentity(for: "delete.example.com") == nil)
    }

    private func makeManager() -> CustomCertificateManager {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RockxyCustomCertificateTests-\(UUID().uuidString)")
            .appendingPathComponent("custom.json")
        return CustomCertificateManager(storageURL: url, secureStore: MemorySecureDataStore())
    }

    private func makeLeafIdentity(host: String) throws -> (certificatePEM: String, privateKeyPEM: String) {
        let root = try RootCAGenerator.generate()
        let leaf = try HostCertGenerator.generate(host: host, issuer: root.certificate, issuerKey: root.privateKey)
        return (try pem(leaf.certificate), leaf.privateKey.pemRepresentation)
    }

    private func pem(_ certificate: Certificate) throws -> String {
        var serializer = DER.Serializer()
        try certificate.serialize(into: &serializer)
        return PEMDocument(type: "CERTIFICATE", derBytes: serializer.serializedBytes).pemString
    }
}
