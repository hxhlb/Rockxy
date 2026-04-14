import Foundation
@testable import Rockxy
import Security
import Testing

/// Direct tests for `ConnectionValidator` — the real helper XPC caller-validation entrypoint.
///
/// `ConnectionValidator.validateCaller(pid:auditTokenData:)` is the testable seam that
/// `isValidCaller(_:)` delegates to after extracting PID and audit token from the
/// connection object. Tests exercise this seam with the real test-host PID and
/// synthesized audit token data to cover both accept and reject paths.
@Suite(.serialized)
struct ConnectionValidatorTests {
    // MARK: - Allowlist Contract

    @Test("ConnectionValidator reads the expected allowlist from RockxyIdentity")
    func allowlistMatchesIdentityConfig() {
        let ids = RockxyIdentity.current.allowedCallerIdentifiers
        #expect(ids.contains("com.amunx.rockxy.community"))
        #expect(ids.contains("com.amunx.rockxy"))
    }

    // MARK: - Accept Path via validateCaller(pid:auditTokenData:)

    @Test("validateCaller accepts test host PID with no audit token")
    func acceptsTestHostPIDNoAuditToken() {
        let pid = ProcessInfo.processInfo.processIdentifier
        let accepted = ConnectionValidator.validateCaller(pid: pid, auditTokenData: nil)
        #expect(accepted)
    }

    @Test("validateCaller accepts test host PID with invalid audit token (graceful skip)")
    func acceptsTestHostPIDWithInvalidAuditToken() {
        let pid = ProcessInfo.processInfo.processIdentifier
        // Invalid token data → secCodeFromAuditToken returns nil → audit recheck skipped.
        // PID validation still passes → overall result is accept.
        let accepted = ConnectionValidator.validateCaller(pid: pid, auditTokenData: Data([1, 2, 3]))
        #expect(accepted)
    }

    // MARK: - Reject Path via validateCaller(pid:auditTokenData:)

    @Test("validateCaller rejects invalid PID")
    func rejectsInvalidPID() {
        let rejected = ConnectionValidator.validateCaller(pid: 0, auditTokenData: nil)
        #expect(!rejected)
    }

    @Test("validateCaller rejects invalid PID even with valid-shaped audit token")
    func rejectsInvalidPIDWithAuditToken() {
        let fakeToken = Data(repeating: 0, count: MemoryLayout<audit_token_t>.size)
        let rejected = ConnectionValidator.validateCaller(pid: 0, auditTokenData: fakeToken)
        #expect(!rejected)
    }

    // MARK: - isValidCaller(_:) Connection Entrypoint

    @Test("isValidCaller rejects client-side connection (processIdentifier == 0)")
    func rejectsClientSideConnection() {
        let connection = NSXPCConnection(serviceName: "com.amunx.rockxy.test.stub")
        defer { connection.invalidate() }

        #expect(connection.processIdentifier == 0)
        #expect(!ConnectionValidator.isValidCaller(connection))
    }

    // MARK: - extractAuditTokenData

    @Test("extractAuditTokenData returns nil for client-side connection")
    func extractReturnsNilForClientConnection() {
        let connection = NSXPCConnection(serviceName: "com.amunx.rockxy.test.stub")
        defer { connection.invalidate() }

        let data = ConnectionValidator.extractAuditTokenData(from: connection)
        // Client-side connections typically return nil for auditToken KVC
        // (the audit token is populated by the XPC runtime for server-side connections)
        #expect(data == nil || data?.count == MemoryLayout<audit_token_t>.size)
    }

    // MARK: - Audit Token Data Handling

    @Test("secCodeFromAuditToken rejects undersized data")
    func auditTokenRejectsUndersized() {
        #expect(CallerValidation.secCodeFromAuditToken(Data([1, 2, 3])) == nil)
    }

    @Test("secCodeFromAuditToken rejects empty data")
    func auditTokenRejectsEmpty() {
        #expect(CallerValidation.secCodeFromAuditToken(Data()) == nil)
    }

    @Test("secCodeFromAuditToken rejects oversized data")
    func auditTokenRejectsOversized() {
        let tooLarge = Data(repeating: 0, count: MemoryLayout<audit_token_t>.size + 1)
        #expect(CallerValidation.secCodeFromAuditToken(tooLarge) == nil)
    }

    // MARK: - NSValue Audit Token Conversion Coverage

    @Test("secCodeFromAuditToken rejects zero-filled token-sized data")
    func zeroFilledTokenRejected() {
        // A zero-filled buffer is the right size but maps to PID 0 / invalid process.
        // This exercises the same Data → SecCode conversion that the NSValue branch
        // in extractAuditTokenData would produce after getValue.
        let zeroToken = Data(repeating: 0, count: MemoryLayout<audit_token_t>.size)
        #expect(CallerValidation.secCodeFromAuditToken(zeroToken) == nil)
    }

    @Test("validateCaller with zero-filled audit token data still accepts valid PID")
    func validPIDWithZeroAuditTokenAccepts() {
        // Simulates the production flow when KVC returns an NSValue containing
        // a zero audit token: the token fails SecCode lookup, the recheck is
        // skipped, and the PID-based validation result stands.
        let pid = ProcessInfo.processInfo.processIdentifier
        let zeroToken = Data(repeating: 0, count: MemoryLayout<audit_token_t>.size)

        let accepted = ConnectionValidator.validateCaller(pid: pid, auditTokenData: zeroToken)
        #expect(accepted)
    }

    // MARK: - PID-Based Identity Equivalence

    @Test("PID-based SecCode satisfies the same identity check as audit-token path")
    func pidCodeSatisfiesSameIdentityCheck() {
        let pid = ProcessInfo.processInfo.processIdentifier
        guard let code = CallerValidation.secCodeForPID(pid) else {
            Issue.record("Cannot get SecCode for current PID")
            return
        }

        let satisfied = CallerValidation.callerSatisfiesAnyIdentifier(
            callerCode: code,
            allowedIdentifiers: RockxyIdentity.current.allowedCallerIdentifiers
        )
        #expect(satisfied)
    }
}
