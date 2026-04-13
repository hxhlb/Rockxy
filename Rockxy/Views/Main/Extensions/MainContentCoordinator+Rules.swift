import Foundation

// Extends `MainContentCoordinator` with rules behavior for the main workspace.

// MARK: - MainContentCoordinator + Rules

/// Coordinator extension for proxy rule management (block, map, breakpoint, throttle).
/// Delegates to `RulePolicyGate` which enforces per-category quotas before
/// forwarding to `RuleSyncService`.
extension MainContentCoordinator {
    // MARK: - Rule Management

    func addRule(_ rule: ProxyRule) {
        Task { await RulePolicyGate.shared.addRule(rule) }
    }

    func removeRule(id: UUID) {
        Task { await RulePolicyGate.shared.removeRule(id: id) }
    }

    func toggleRule(id: UUID) {
        Task { await RulePolicyGate.shared.toggleRule(id: id) }
    }

    func createBreakpointRule(for transaction: HTTPTransaction) {
        let context = BreakpointEditorContextBuilder.fromTransaction(transaction)
        BreakpointEditorContextStore.shared.setPending(context)
        NotificationCenter.default.post(name: .openBreakpointRulesWindow, object: nil)
    }
}
