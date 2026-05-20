import SwiftUI

// Presents the breakpoint window for breakpoint review and editing.

// MARK: - BreakpointQueueLayoutMode

private enum BreakpointQueueLayoutMode: String, CaseIterable {
    case horizontal
    case vertical
    case reversed

    var next: BreakpointQueueLayoutMode {
        switch self {
        case .horizontal: .vertical
        case .vertical: .reversed
        case .reversed: .horizontal
        }
    }

    var systemImage: String {
        switch self {
        case .horizontal: "rectangle.split.2x1"
        case .vertical: "rectangle.split.1x2"
        case .reversed: "rectangle.split.2x1"
        }
    }

    var help: String {
        switch self {
        case .horizontal:
            String(localized: "Switch Layout Mode: Vertical")
        case .vertical:
            String(localized: "Switch Layout Mode: Reversed")
        case .reversed:
            String(localized: "Switch Layout Mode: Horizontal")
        }
    }
}

// MARK: - BreakpointWindowView

/// Standalone window for managing breakpoint-paused requests.
/// The queue mirrors a native macOS proxy table while the editor keeps the
/// existing breakpoint editing workflow on the selected item.
struct BreakpointWindowView: View {
    // MARK: Internal

    var body: some View {
        VStack(spacing: 0) {
            mainContent
            Divider()
            queueToolbar
            Divider()
            actionBar
        }
        .frame(minWidth: 960, minHeight: 560)
    }

    // MARK: Private

    @Environment(\.openWindow) private var openWindow
    @AppStorage("breakpointQueueLayoutMode") private var layoutModeRaw = BreakpointQueueLayoutMode.horizontal.rawValue

    private let manager = BreakpointManager.shared
    private let windowModel = BreakpointWindowModel.shared

    private var layoutMode: BreakpointQueueLayoutMode {
        get { BreakpointQueueLayoutMode(rawValue: layoutModeRaw) ?? .horizontal }
        nonmutating set { layoutModeRaw = newValue.rawValue }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch layoutMode {
        case .horizontal:
            HSplitView {
                queueTable.frame(minWidth: 500, idealWidth: 620, maxHeight: .infinity)
                editor.frame(minWidth: 420, maxHeight: .infinity)
            }
        case .vertical:
            VSplitView {
                queueTable.frame(minHeight: 180, idealHeight: 260, maxHeight: .infinity)
                editor.frame(minHeight: 260, maxHeight: .infinity)
            }
        case .reversed:
            HSplitView {
                editor.frame(minWidth: 420, maxHeight: .infinity)
                queueTable.frame(minWidth: 500, idealWidth: 620, maxHeight: .infinity)
            }
        }
    }

    private var queueTable: some View {
        BreakpointQueueTableView(manager: manager)
    }

    private var editor: some View {
        BreakpointEditorView(manager: manager, windowModel: windowModel)
    }

    private var queueToolbar: some View {
        HStack(spacing: 8) {
            Button(String(localized: "Manage Rules")) {
                openWindow(id: "breakpointRules")
            }
            .keyboardShortcut("b", modifiers: .command)

            Spacer()

            Button {
                layoutMode = layoutMode.next
            } label: {
                Label(String(localized: "Switch Layout"), systemImage: layoutMode.systemImage)
                    .labelStyle(.iconOnly)
            }
            .help(layoutMode.help)

            Divider()
                .frame(height: 22)

            moreMenu
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                resolveSelected(.cancel)
            } label: {
                Label(String(localized: "Continue"), systemImage: "play.fill")
            }
            .keyboardShortcut(".", modifiers: .command)
            .disabled(!hasSelection)

            Button {
                resolveSelected(.abort)
            } label: {
                Label(String(localized: "Abort"), systemImage: "xmark.octagon")
            }
            .keyboardShortcut("\\", modifiers: .command)
            .disabled(!hasSelection)

            Button {
                resolveSelected(.cancel)
            } label: {
                Label(String(localized: "Skip Once"), systemImage: "forward.frame")
            }
            .disabled(!hasSelection)

            Spacer()

            Button {
                resolveSelected(.execute)
            } label: {
                Label(String(localized: "Execute"), systemImage: "arrowshape.turn.up.right.fill")
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!hasSelection)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var moreMenu: some View {
        Menu {
            Button(String(localized: "Execute")) {
                resolveSelected(.execute)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!hasSelection)

            Button(String(localized: "Execute All")) {
                manager.resolveAll(decision: .execute)
            }
            .keyboardShortcut(.return, modifiers: [.command, .shift])
            .disabled(!manager.hasPausedItems)

            Divider()

            Button(String(localized: "Continue")) {
                resolveSelected(.cancel)
            }
            .keyboardShortcut(".", modifiers: .command)
            .disabled(!hasSelection)

            Button(String(localized: "Continue All")) {
                manager.resolveAll(decision: .cancel)
            }
            .keyboardShortcut(".", modifiers: [.command, .shift])
            .disabled(!manager.hasPausedItems)

            Divider()

            Button(String(localized: "Abort")) {
                resolveSelected(.abort)
            }
            .keyboardShortcut("\\", modifiers: .command)
            .disabled(!hasSelection)

            Button(String(localized: "Abort All")) {
                manager.resolveAll(decision: .abort)
            }
            .keyboardShortcut("\\", modifiers: [.command, .shift])
            .disabled(!manager.hasPausedItems)

            Divider()

            Menu(String(localized: "Advanced Settings")) {
                Button(layoutMode.help) {
                    layoutMode = layoutMode.next
                }
                Button(String(localized: "Templates...")) {
                    openWindow(id: "breakpointTemplates")
                }
            }

            Divider()

            Button(String(localized: "Add Rule")) {
                openWindow(id: "breakpointRules")
            }
            .keyboardShortcut("b", modifiers: .command)
        } label: {
            Label(String(localized: "More"), systemImage: "ellipsis.circle")
        }
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var hasSelection: Bool {
        manager.selectedItemId != nil
    }

    private func resolveSelected(_ decision: BreakpointDecision) {
        guard let selectedId = manager.selectedItemId else {
            return
        }
        manager.resolve(id: selectedId, decision: decision)
    }
}

// MARK: - BreakpointQueueTableView

private struct BreakpointQueueTableView: View {
    @Bindable var manager: BreakpointManager

    private let columns: [(title: String, width: CGFloat)] = [
        (String(localized: "ID"), 54),
        (String(localized: "URL"), 300),
        (String(localized: "Client"), 160),
        (String(localized: "Method"), 94),
        (String(localized: "Status"), 104),
        (String(localized: "Code"), 72),
        (String(localized: "Time"), 112),
        (String(localized: "Duration"), 104),
        (String(localized: "Request"), 92),
        (String(localized: "Response"), 104),
        (String(localized: "Query Name"), 150),
    ]

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = max(tableWidth, geometry.size.width)
            let contentHeight = max(geometry.size.height, headerHeight + 1)

            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        headerRow
                            .frame(width: contentWidth, alignment: .leading)
                        Divider()
                        ForEach(manager.pausedItems) { item in
                            queueRow(item)
                            Divider()
                        }
                    }
                    .frame(width: contentWidth, alignment: .topLeading)
                    .frame(minHeight: contentHeight, alignment: .topLeading)

                    if manager.pausedItems.isEmpty {
                        emptyState
                            .frame(
                                width: contentWidth,
                                height: max(0, contentHeight - headerHeight - 1),
                                alignment: .center
                            )
                            .padding(.top, headerHeight + 1)
                    }
                }
                .frame(width: contentWidth, alignment: .topLeading)
                .frame(minHeight: contentHeight, alignment: .topLeading)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var tableWidth: CGFloat {
        columns.reduce(0) { $0 + $1.width }
    }

    private var headerHeight: CGFloat {
        32
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(String(localized: "No Breakpoints"))
                .font(.title3.weight(.semibold))
            Text(String(localized: "Click \"Manage Rules\" button to create your first Breakpoint Rules"))
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                Text(column.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: column.width, height: headerHeight, alignment: .leading)
                    .padding(.leading, 8)
                    .overlay(alignment: .trailing) {
                        Divider().frame(height: 20)
                    }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func queueRow(_ item: PausedBreakpointItem) -> some View {
        let isSelected = manager.selectedItemId == item.id
        return HStack(spacing: 0) {
            Group {
                cell("\(item.sequenceNumber)", width: columns[0].width, monospaced: true)
                cell(item.url, width: columns[1].width, monospaced: true, help: item.url)
                cell(item.client, width: columns[2].width)
                cell(item.method, width: columns[3].width, monospaced: true)
                cell(String(localized: "Paused"), width: columns[4].width, color: .orange)
                cell(
                    item.statusCode.map(String.init) ?? "",
                    width: columns[5].width,
                    color: statusColor(for: item.statusCode)
                )
            }
            Group {
                timeCell(item.createdAt, width: columns[6].width)
                durationCell(item.createdAt, width: columns[7].width)
                phaseCell(item.phase == .request ? "REQ" : "", width: columns[8].width)
                phaseCell(item.phase == .response ? "RES" : "", width: columns[9].width)
                cell(item.queryName, width: columns[10].width)
            }
        }
        .frame(height: 28)
        .background(isSelected ? Color.accentColor.opacity(0.18) : rowBackground(for: item))
        .contentShape(Rectangle())
        .onTapGesture {
            manager.selectedItemId = item.id
        }
    }

    private func cell(
        _ value: String,
        width: CGFloat,
        color: Color = .primary,
        monospaced: Bool = false,
        help: String? = nil
    )
        -> some View
    {
        Text(value)
            .font(monospaced ? .system(.caption, design: .monospaced) : .caption)
            .foregroundStyle(color)
            .lineLimit(1)
            .help(help ?? value)
            .frame(width: width, alignment: .leading)
            .padding(.leading, 8)
    }

    private func timeCell(_ date: Date, width: CGFloat) -> some View {
        Text(date, format: .dateTime.hour().minute().second())
            .font(.system(.caption, design: .monospaced))
            .monospacedDigit()
            .frame(width: width, alignment: .leading)
            .padding(.leading, 8)
    }

    private func durationCell(_ date: Date, width: CGFloat) -> some View {
        ElapsedTimeLabel(since: date)
            .frame(width: width, alignment: .leading)
            .padding(.leading, 8)
    }

    private func phaseText(_ value: String) -> some View {
        Text(value)
            .font(.system(.body, design: .monospaced).weight(.semibold))
            .foregroundStyle(value == "REQ" ? Color.green : Color.blue)
    }

    private func phaseCell(_ value: String, width: CGFloat) -> some View {
        phaseText(value)
            .font(.system(.caption, design: .monospaced).weight(.semibold))
            .frame(width: width, alignment: .leading)
            .padding(.leading, 8)
    }

    private func rowBackground(for item: PausedBreakpointItem) -> Color {
        item.sequenceNumber.isMultiple(of: 2)
            ? Color(nsColor: .textBackgroundColor)
            : Color(nsColor: .controlBackgroundColor).opacity(0.45)
    }

    private func statusColor(for statusCode: Int?) -> Color {
        guard let statusCode else {
            return Color.secondary
        }
        switch statusCode {
        case 200 ..< 300: return Color.green
        case 300 ..< 400: return Color.blue
        case 400 ..< 500: return Color.orange
        case 500...: return Color.red
        default: return Color.secondary
        }
    }
}
