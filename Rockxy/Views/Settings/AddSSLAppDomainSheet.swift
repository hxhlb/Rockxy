import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - AddSSLAppDomainSheet

/// Sheet for adding apps or domains to the SSL Proxying list.
/// Shows running applications grouped hierarchically with search.
struct AddSSLAppDomainSheet: View {
    // MARK: Lifecycle

    init(onAdd: @escaping ([String]) -> Void) {
        self.onAdd = onAdd
    }

    // MARK: Internal

    let onAdd: ([String]) -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            searchSection
            Divider()
            listSection
            footerHint
            Divider()
            buttonBar
        }
        .frame(width: 500, height: 520)
        .onAppear { refreshRunningApps() }
    }

    // MARK: Private

    private struct RunningAppItem: Identifiable, Hashable {
        let id: String
        let name: String
        let bundleIdentifier: String?
        let icon: NSImage?

        static func == (lhs: RunningAppItem, rhs: RunningAppItem) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var runningApps: [RunningAppItem] = []
    @State private var selectedItemID: String?
    @State private var showAddDomainSheet = false
    @FocusState private var isSearchFocused: Bool

    private var filteredApps: [RunningAppItem] {
        guard !searchText.isEmpty else {
            return runningApps
        }
        return runningApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var headerSection: some View {
        HStack {
            Text(String(localized: "Add favorite app or domain"))
                .font(.system(size: 13))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var searchSection: some View {
        HStack {
            TextField(
                String(localized: "Search app or domain"),
                text: $searchText,
                prompt: Text(String(localized: "Search app or domain (⌘⇧F)"))
            )
            .textFieldStyle(.roundedBorder)
            .focused($isSearchFocused)
            .onAppear { isSearchFocused = true }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var listSection: some View {
        List(selection: $selectedItemID) {
            Section {
                ForEach(filteredApps) { app in
                    HStack(spacing: 8) {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "app.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 16, height: 16)
                        }

                        Text(app.name)
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }
                    .tag(app.id)
                }
            } header: {
                HStack {
                    Image(systemName: "folder.fill")
                        .font(.caption)
                    Text(String(localized: "Apps"))
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text("\(filteredApps.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var footerHint: some View {
        HStack {
            Spacer()
            Text(String(localized: "Launch your app/domain to see it in the list"))
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var buttonBar: some View {
        HStack(spacing: 8) {
            Button(String(localized: "Cancel")) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Menu {
                Button(String(localized: "App…")) {
                    pickAppFromDisk()
                }
                Button(String(localized: "Domain…")) {
                    showAddDomainSheet = true
                }
            } label: {
                HStack(spacing: 4) {
                    Text(String(localized: "Select"))
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button(String(localized: "Add")) {
                addSelectedItems()
            }
            .disabled(selectedItemID == nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .sheet(isPresented: $showAddDomainSheet) {
            AddSSLDomainSheet { domain in
                onAdd([domain])
                dismiss()
            }
        }
    }

    private func refreshRunningApps() {
        let workspace = NSWorkspace.shared
        var seen = Set<String>()
        var apps: [RunningAppItem] = []

        for app in workspace.runningApplications {
            guard app.activationPolicy == .regular || app.activationPolicy == .accessory else {
                continue
            }
            let name = app.localizedName ?? app.bundleIdentifier ?? "Unknown"
            let key = name.lowercased()
            guard !seen.contains(key) else {
                continue
            }
            seen.insert(key)

            apps.append(RunningAppItem(
                id: app.bundleIdentifier ?? name,
                name: name,
                bundleIdentifier: app.bundleIdentifier,
                icon: app.icon
            ))
        }

        apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        runningApps = apps
    }

    private func addSelectedItems() {
        guard let selectedID = selectedItemID else {
            return
        }
        if let app = runningApps.first(where: { $0.id == selectedID }) {
            let domain = "*.\(app.name.lowercased().replacingOccurrences(of: " ", with: ""))"
            onAdd([domain])
        }
        dismiss()
    }

    private func pickAppFromDisk() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = String(localized: "Select an application")

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        guard let bundle = Bundle(url: url),
              let name = bundle.infoDictionary?["CFBundleName"] as? String
              ?? bundle.infoDictionary?["CFBundleDisplayName"] as? String else
        {
            return
        }

        let domain = "*.\(name.lowercased().replacingOccurrences(of: " ", with: ""))"
        onAdd([domain])
        dismiss()
    }
}
