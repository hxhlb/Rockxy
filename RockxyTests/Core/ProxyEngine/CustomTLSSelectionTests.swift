import Crypto
import Foundation
import NIOSSL
import SwiftASN1
@testable import Rockxy
import Testing
import X509

// MARK: - CustomTLSSelectionTests

struct CustomTLSSelectionTests {
    @Test("server TLS configuration accepts custom server identity")
    func serverTLSConfigurationUsesCustomIdentity() throws {
        let identity = try makeIdentity(host: "pinned.example.com")
        let config = try TLSInterceptHandler.makeServerTLSConfiguration(identity: identity)

        #expect(config.certificateChain.count == 1)
        #expect(config.privateKey != nil)
        #expect(config.applicationProtocols == ["http/1.1"])
    }

    @Test("client TLS configuration includes matching identity and keeps full verification")
    func clientTLSConfigurationIncludesIdentity() throws {
        let identity = try makeIdentity(host: "mtls.example.com")
        let config = try HTTPSProxyRelayHandler.makeClientTLSConfiguration(clientIdentity: identity)

        #expect(config.certificateVerification == .fullVerification)
        #expect(config.certificateChain.count == 1)
        #expect(config.privateKey != nil)
    }

    @Test("client TLS configuration omits identity when there is no match and keeps full verification")
    func clientTLSConfigurationWithoutIdentity() throws {
        let config = try HTTPSProxyRelayHandler.makeClientTLSConfiguration(clientIdentity: nil)

        #expect(config.certificateVerification == .fullVerification)
        #expect(config.certificateChain.isEmpty)
        #expect(config.privateKey == nil)
    }

    @Test("default generated certificate remains available when no custom server match exists")
    func defaultGeneratedCertificateFallback() throws {
        let manager = CustomCertificateManager(
            storageURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("RockxyTLSSelection-\(UUID().uuidString)")
                .appendingPathComponent("custom.json"),
            secureStore: MemorySecureDataStoreForTLS()
        )

        #expect(manager.serverIdentity(for: "fallback.example.com") == nil)
    }

    private func makeIdentity(host: String) throws -> CustomTLSIdentity {
        let root = try RootCAGenerator.generate()
        let leaf = try HostCertGenerator.generate(host: host, issuer: root.certificate, issuerKey: root.privateKey)
        var serializer = DER.Serializer()
        try leaf.certificate.serialize(into: &serializer)
        let certificatePEM = PEMDocument(type: "CERTIFICATE", derBytes: serializer.serializedBytes).pemString
        return CustomTLSIdentity(certificateChainPEM: [certificatePEM], privateKeyPEM: leaf.privateKey.pemRepresentation)
    }
}

private final class MemorySecureDataStoreForTLS: SecureDataStore, @unchecked Sendable {
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
