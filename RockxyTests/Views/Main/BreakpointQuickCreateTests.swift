import Foundation
@testable import Rockxy
import Testing

struct BreakpointQuickCreateTests {
    @Test("Transaction breakpoint builder includes method and normalized path")
    @MainActor
    func transactionBuilder() {
        let transaction = TestFixtures.makeTransaction(
            method: "PATCH",
            url: "https://api.example.com/v1/profile?include=team",
            statusCode: 200
        )

        let rule = BreakpointRuleBuilder.fromTransaction(transaction)
        let pattern = rule.matchCondition.urlPattern ?? ""

        #expect(rule.name == "Breakpoint — PATCH api.example.com/v1/profile")
        #expect(rule.matchCondition.method == "PATCH")
        #expect(pattern.contains(#"api\.example\.com"#))
        #expect(pattern.contains(#"\/v1\/profile"#))
        #expect(pattern.contains(#"?.*)?$"#))

        if case let .breakpoint(phase) = rule.action {
            #expect(phase == .both)
        } else {
            Issue.record("Expected breakpoint action")
        }
    }

    @Test("Transaction breakpoint builder normalizes empty path to slash")
    @MainActor
    func transactionBuilderNormalizesEmptyPath() {
        let transaction = TestFixtures.makeTransaction(
            method: "GET",
            url: "https://api.example.com",
            statusCode: 200
        )

        let rule = BreakpointRuleBuilder.fromTransaction(transaction)
        let pattern = rule.matchCondition.urlPattern ?? ""

        #expect(rule.name == "Breakpoint — GET api.example.com/")
        #expect(pattern.contains(#"api\.example\.com\/"#))
        #expect(pattern.contains(#"?.*)?$"#))
    }

    @Test("Domain breakpoint builder omits method and scopes to domain")
    func domainBuilder() {
        let rule = BreakpointRuleBuilder.fromDomain("cdn.example.com")

        #expect(rule.name == "Breakpoint — cdn.example.com")
        #expect(rule.matchCondition.method == nil)
        #expect(rule.matchCondition.urlPattern == #".*cdn\.example\.com/.*"#)

        if case let .breakpoint(phase) = rule.action {
            #expect(phase == .both)
        } else {
            Issue.record("Expected breakpoint action")
        }
    }
}
