import AppKit
import SwiftUI

/// Native split container for the request table and inspector.
/// Uses `NSSplitViewItem` collapse animation so inspector toggles feel closer to macOS sidebars.
struct InspectorSplitView<PrimaryContent: View, InspectorContent: View>: NSViewControllerRepresentable {
    let layout: InspectorLayout
    let primaryContent: PrimaryContent
    let inspectorContent: InspectorContent

    init(
        layout: InspectorLayout,
        @ViewBuilder primary: () -> PrimaryContent,
        @ViewBuilder inspector: () -> InspectorContent
    ) {
        self.layout = layout
        self.primaryContent = primary()
        self.inspectorContent = inspector()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(layout: layout)
    }

    func makeNSViewController(context: Context) -> NSSplitViewController {
        let splitViewController = NSSplitViewController()
        splitViewController.splitView.isVertical = layout.isVerticalSplit
        splitViewController.splitView.dividerStyle = .thin

        let primaryController = NSHostingController(rootView: primaryContent)
        let primaryItem = NSSplitViewItem(viewController: primaryController)

        let inspectorController = NSHostingController(rootView: inspectorContent)
        let inspectorItem = NSSplitViewItem(viewController: inspectorController)
        inspectorItem.canCollapse = true

        applyThickness(for: layout, primaryItem: primaryItem, inspectorItem: inspectorItem)

        splitViewController.addSplitViewItem(primaryItem)
        splitViewController.addSplitViewItem(inspectorItem)
        inspectorItem.isCollapsed = layout == .hidden

        context.coordinator.primaryController = primaryController
        context.coordinator.inspectorController = inspectorController
        context.coordinator.primaryItem = primaryItem
        context.coordinator.inspectorItem = inspectorItem
        context.coordinator.lastLayout = layout
        context.coordinator.lastVisibleLayout = layout.visibleFallback

        return splitViewController
    }

    func updateNSViewController(_ splitViewController: NSSplitViewController, context: Context) {
        context.coordinator.primaryController?.rootView = primaryContent
        context.coordinator.inspectorController?.rootView = inspectorContent

        guard let primaryItem = context.coordinator.primaryItem,
              let inspectorItem = context.coordinator.inspectorItem
        else {
            return
        }

        let visibleLayout = layout.visibleFallback(previous: context.coordinator.lastVisibleLayout)
        if layout != .hidden {
            context.coordinator.lastVisibleLayout = layout
        }

        if splitViewController.splitView.isVertical != visibleLayout.isVerticalSplit {
            splitViewController.splitView.isVertical = visibleLayout.isVerticalSplit
            splitViewController.splitView.adjustSubviews()
        }

        applyThickness(for: visibleLayout, primaryItem: primaryItem, inspectorItem: inspectorItem)
        animateCollapseIfNeeded(inspectorItem, isCollapsed: layout == .hidden, context: context)
        context.coordinator.lastLayout = layout
    }

    final class Coordinator {
        var primaryController: NSHostingController<PrimaryContent>?
        var inspectorController: NSHostingController<InspectorContent>?
        var primaryItem: NSSplitViewItem?
        var inspectorItem: NSSplitViewItem?
        var lastLayout: InspectorLayout
        var lastVisibleLayout: InspectorLayout

        init(layout: InspectorLayout) {
            self.lastLayout = layout
            self.lastVisibleLayout = layout.visibleFallback
        }
    }

    private func applyThickness(
        for layout: InspectorLayout,
        primaryItem: NSSplitViewItem,
        inspectorItem: NSSplitViewItem
    ) {
        switch layout {
        case .hidden, .right:
            primaryItem.minimumThickness = 300
            inspectorItem.minimumThickness = 300
        case .bottom:
            primaryItem.minimumThickness = 200
            inspectorItem.minimumThickness = 200
        }
    }

    private func animateCollapseIfNeeded(
        _ inspectorItem: NSSplitViewItem,
        isCollapsed: Bool,
        context: Context
    ) {
        guard context.coordinator.lastLayout == .hidden || layout == .hidden else {
            inspectorItem.isCollapsed = isCollapsed
            return
        }
        guard inspectorItem.isCollapsed != isCollapsed else { return }

        NSAnimationContext.runAnimationGroup { animationContext in
            animationContext.duration = 0.22
            animationContext.allowsImplicitAnimation = true
            animationContext.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            inspectorItem.animator().isCollapsed = isCollapsed
        }
    }
}

private extension InspectorLayout {
    var isVerticalSplit: Bool {
        switch self {
        case .hidden, .right:
            true
        case .bottom:
            false
        }
    }

    var visibleFallback: InspectorLayout {
        visibleFallback(previous: .right)
    }

    func visibleFallback(previous: InspectorLayout) -> InspectorLayout {
        switch self {
        case .hidden:
            previous == .bottom ? .bottom : .right
        case .right, .bottom:
            self
        }
    }
}
