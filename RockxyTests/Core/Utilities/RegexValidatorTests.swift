import Foundation
@testable import Rockxy
import Testing

struct RegexValidatorTests {
    @Test("Compiles valid simple pattern")
    func validSimplePattern() {
        let result = RegexValidator.compile(".*\\.example\\.com")
        if case .success = result {
            // pass
        } else {
            Issue.record("Expected success for valid pattern")
        }
    }

    @Test("Compiles valid URL pattern")
    func validURLPattern() {
        let result = RegexValidator.compile("https?://api\\.example\\.com/v[0-9]+/.*")
        if case let .success(regex) = result {
            #expect(regex.pattern == "https?://api\\.example\\.com/v[0-9]+/.*")
        } else {
            Issue.record("Expected success for valid URL pattern")
        }
    }

    @Test("Rejects invalid regex (unbalanced parentheses)")
    func invalidUnbalancedParens() {
        let result = RegexValidator.compile("((abc)")
        if case .failure(.invalidPattern) = result {
            // pass
        } else {
            Issue.record("Expected failure for unbalanced parentheses")
        }
    }

    @Test("Rejects invalid regex (bad character class)")
    func invalidCharClass() {
        let result = RegexValidator.compile("[abc")
        if case .failure(.invalidPattern) = result {
            // pass
        } else {
            Issue.record("Expected failure for bad character class")
        }
    }

    @Test("Rejects pattern exceeding max length")
    func patternTooLong() {
        let longPattern = String(repeating: "a", count: 501)
        let result = RegexValidator.compile(longPattern)
        if case let .failure(.patternTooLong(length)) = result {
            #expect(length == 501)
        } else {
            Issue.record("Expected patternTooLong failure")
        }
    }

    @Test("Accepts pattern at exactly max length")
    func patternAtMaxLength() {
        let pattern = String(repeating: "a", count: 500)
        let result = RegexValidator.compile(pattern)
        if case .success = result {
            // pass
        } else {
            Issue.record("Expected success for pattern at max length")
        }
    }

    @Test("Compiles wildcard pattern")
    func wildcardPattern() {
        let result = RegexValidator.compile(".*")
        if case .success = result {
            // pass
        } else {
            Issue.record("Expected success for wildcard pattern")
        }
    }

    @Test("Rejects empty-looking invalid pattern")
    func invalidLoneBackslash() {
        let result = RegexValidator.compile("\\")
        if case .failure(.invalidPattern) = result {
            // pass
        } else {
            Issue.record("Expected failure for lone backslash")
        }
    }
}
