//
//  CustomServicesScreen.swift
//  Edx
//
//  Manage user-defined long-running services (start/stop, menu bar visibility, logs).
//

import SwiftUI
import AppKit

struct CustomServicesScreen: View {
    @State private var manager = CustomServiceManager.shared

    @State private var editorPresentation: CustomServiceEditorPresentation?
    @State private var logViewerService: CustomService?
    @State private var serviceToDelete: CustomService?

    @AppStorage(CustomServiceManager.autoCheckEnabledKey) private var autoCheckEnabled = true
    @AppStorage(CustomServiceManager.autoCheckIntervalHoursKey) private var autoCheckIntervalHours = 6

    @State private var showTokenSheet = false

    var body: some View {
        Group {
            if manager.services.isEmpty {
                emptyState
            } else {
                serviceList
            }
        }
        .navigationTitle("nav.customServices".localized())
        .toolbar {
            if manager.services.contains(where: { $0.githubRepository != nil }) {
                ToolbarItem {
                    updatesMenu
                }
            }
            ToolbarItem {
                Button {
                    openEditor()
                } label: {
                    Label("custom.service.add".localized(), systemImage: "plus")
                }
                .help("custom.service.add".localized())
            }
        }
        .sheet(item: $editorPresentation) { presentation in
            CustomServiceEditorSheet(service: presentation.service) { result in
                if manager.services.contains(where: { $0.id == result.id }) {
                    manager.updateService(result)
                } else {
                    manager.addService(result)
                }
            }
        }
        .sheet(item: $logViewerService) { service in
            CustomServiceLogViewer(service: service)
        }
        .sheet(isPresented: $showTokenSheet) {
            GitHubTokenSheet()
        }
        .alert(
            "custom.service.delete.title".localized(),
            isPresented: Binding(
                get: { serviceToDelete != nil },
                set: { if !$0 { serviceToDelete = nil } }
            ),
            presenting: serviceToDelete
        ) { service in
            Button("action.delete".localized(), role: .destructive) {
                manager.deleteService(service)
                serviceToDelete = nil
            }
            Button("action.cancel".localized(), role: .cancel) {
                serviceToDelete = nil
            }
        } message: { service in
            Text(String(format: "custom.service.delete.message".localized(), service.name))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("custom.service.empty".localized(), systemImage: "terminal")
        } description: {
            Text("custom.service.empty.description".localized())
        } actions: {
            Button {
                openEditor()
            } label: {
                Text("custom.service.addFirst".localized())
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Service List

    private var serviceList: some View {
        List {
            Section {
                ForEach(manager.services) { service in
                    CustomServiceRow(
                        service: service,
                        onToggle: { toggle(service) },
                        onEdit: {
                            openEditor(for: service)
                        },
                        onLogs: { logViewerService = service },
                        onCheckUpdates: { manager.checkForUpdates(service) },
                        onOpenRelease: { manager.openLatestRelease(for: service) },
                        onUpdate: { manager.performUpdate(service) },
                        onMarkCurrent: { manager.markLatestAsCurrent(for: service) },
                        onIgnoreVersion: { manager.ignoreLatestVersion(for: service) },
                        onClearIgnore: { manager.clearIgnoredVersion(for: service) },
                        onDelete: { serviceToDelete = service }
                    )
                }
                .onMove { source, destination in
                    manager.moveServices(fromOffsets: source, toOffset: destination)
                }
            } footer: {
                Text("custom.service.footer".localized())
            }
        }
    }

    // MARK: - Updates Menu

    private var updatesMenu: some View {
        Menu {
            Button {
                manager.checkAllForUpdates(force: true)
            } label: {
                Label("custom.service.update.checkAll".localized(), systemImage: "arrow.down.circle")
            }

            Divider()

            Toggle("custom.service.update.autoCheck".localized(), isOn: $autoCheckEnabled)
                .onChange(of: autoCheckEnabled) { _, _ in
                    manager.reconfigureAutoUpdateChecks()
                }

            Picker("custom.service.update.interval".localized(), selection: $autoCheckIntervalHours) {
                Text("custom.service.update.interval.1h".localized()).tag(1)
                Text("custom.service.update.interval.6h".localized()).tag(6)
                Text("custom.service.update.interval.12h".localized()).tag(12)
                Text("custom.service.update.interval.24h".localized()).tag(24)
            }
            .disabled(!autoCheckEnabled)
            .onChange(of: autoCheckIntervalHours) { _, _ in
                manager.reconfigureAutoUpdateChecks()
            }

            Divider()

            Button {
                showTokenSheet = true
            } label: {
                Label("custom.service.update.githubToken".localized(), systemImage: "key")
            }
        } label: {
            Label("custom.service.update.checkAll".localized(), systemImage: "arrow.triangle.2.circlepath")
        }
        .help("custom.service.update.checkAll".localized())
    }

    private func toggle(_ service: CustomService) {
        if manager.isRunning(service.id) {
            manager.stop(service)
        } else {
            manager.start(service)
        }
    }

    private func openEditor(for service: CustomService? = nil) {
        editorPresentation = CustomServiceEditorPresentation(service: service)
    }
}

private struct CustomServiceEditorPresentation: Identifiable {
    let id: UUID
    let service: CustomService?

    init(service: CustomService?) {
        self.service = service
        id = service?.id ?? UUID()
    }
}

// MARK: - Service Row

private struct CustomServiceRow: View {
    let service: CustomService
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onLogs: () -> Void
    let onCheckUpdates: () -> Void
    let onOpenRelease: () -> Void
    let onUpdate: () -> Void
    let onMarkCurrent: () -> Void
    let onIgnoreVersion: () -> Void
    let onClearIgnore: () -> Void
    let onDelete: () -> Void

    @State private var manager = CustomServiceManager.shared

    private var status: CustomServiceStatus {
        manager.status(for: service.id)
    }

    var body: some View {
        HStack(spacing: 12) {
            statusIndicator

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(service.name)
                        .font(.system(.body, weight: .medium))
                    if service.showInMenuBar {
                        Image(systemName: "menubar.rectangle")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .help("custom.service.menuBar.shown".localized())
                    }
                    if service.autoStart {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .help("custom.service.autoStart".localized())
                    }
                }

                Text(service.command)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let updateText {
                    Text(updateText)
                        .font(.caption2)
                        .foregroundStyle(updateColor)
                        .lineLimit(1)
                }

                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(statusColor)
            }

            Spacer()

            controls
        }
        .padding(.vertical, 6)
    }

    private var statusIndicator: some View {
        Group {
            switch status {
            case .starting, .stopping:
                SmallProgressView(size: 10)
            default:
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
            }
        }
        .frame(width: 14)
    }

    @ViewBuilder
    private var controls: some View {
        Button(action: onToggle) {
            Image(systemName: status.isActive ? "stop.fill" : "play.fill")
        }
        .buttonStyle(.borderless)
        .disabled(status == .starting || status == .stopping)
        .help(status.isActive ? "action.stop".localized() : "action.start".localized())

        Button(action: onLogs) {
            Image(systemName: "doc.text")
        }
        .buttonStyle(.borderless)
        .help("custom.service.viewLogs".localized())

        if service.githubRepository != nil {
            Button(action: onCheckUpdates) {
                Image(systemName: updateCheckState.isChecking ? "arrow.triangle.2.circlepath" : "arrow.down.circle")
            }
            .buttonStyle(.borderless)
            .disabled(updateCheckState.isChecking)
            .help("custom.service.update.check".localized())
        }

        if updateCheckState.isUpdating {
            SmallProgressView(size: 12)
                .help("custom.service.update.updating".localized())
        } else if service.isUpdateAvailable {
            Menu {
                if service.normalizedUpdateCommand != nil {
                    Button(action: onUpdate) {
                        Label("custom.service.update.updateNow".localized(), systemImage: "arrow.down.app")
                    }
                    Divider()
                }
                Button(action: onOpenRelease) {
                    Label("custom.service.update.openRelease".localized(), systemImage: "arrow.up.right.square")
                }
                Button(action: onMarkCurrent) {
                    Label("custom.service.update.markCurrent".localized(), systemImage: "checkmark.circle")
                }
                Button(action: onIgnoreVersion) {
                    Label("custom.service.update.ignore".localized(), systemImage: "xmark.circle")
                }
            } label: {
                Image(systemName: service.normalizedUpdateCommand != nil ? "arrow.down.app" : "arrow.up.right.square")
            }
            .menuIndicator(.hidden)
            .buttonStyle(.borderless)
            .fixedSize()
            .help("custom.service.update.available.help".localized())
        } else if isLatestIgnored {
            Button(action: onClearIgnore) {
                Image(systemName: "arrow.uturn.backward.circle")
            }
            .buttonStyle(.borderless)
            .help("custom.service.update.clearIgnore".localized())
        }

        Button(action: onEdit) {
            Image(systemName: "pencil")
        }
        .buttonStyle(.borderless)
        .help("action.edit".localized())

        Button(action: onDelete) {
            Image(systemName: "trash")
                .foregroundStyle(.red)
        }
        .buttonStyle(.borderless)
        .help("action.delete".localized())
    }

    private var updateCheckState: CustomServiceUpdateCheckState {
        manager.updateCheckState(for: service.id)
    }

    /// True when the latest discovered release is the one the user chose to skip.
    private var isLatestIgnored: Bool {
        guard let status = service.updateStatus, status.hasRelease,
              let ignored = service.ignoredVersion else { return false }
        return SemanticVersion.compare(ignored, status.latestVersion) == .orderedSame
    }

    private var updateText: String? {
        if updateCheckState.isUpdating {
            return "custom.service.update.updating".localized()
        }
        if updateCheckState.isChecking {
            return "custom.service.update.checking".localized()
        }
        if let message = updateCheckState.message, !message.isEmpty {
            return message
        }
        if let error = service.updateStatus?.errorMessage, !error.isEmpty {
            return error
        }
        guard let updateStatus = service.updateStatus, updateStatus.hasRelease else {
            return service.githubRepository == nil ? nil : "custom.service.update.notChecked".localized()
        }
        if service.isUpdateAvailable {
            return String(format: "custom.service.update.available".localized(), updateStatus.latestVersion)
        }
        if let ignored = service.ignoredVersion,
           SemanticVersion.compare(ignored, updateStatus.latestVersion) == .orderedSame {
            return String(format: "custom.service.update.ignored".localized(), ignored)
        }
        return String(format: "custom.service.update.upToDate".localized(), updateStatus.latestVersion)
    }

    private var updateColor: Color {
        if updateCheckState.isChecking { return .secondary }
        if updateCheckState.message != nil || service.updateStatus?.errorMessage != nil { return .orange }
        if service.isUpdateAvailable { return .blue }
        return .secondary
    }

    private var statusColor: Color {
        switch status {
        case .running: return .green
        case .starting, .stopping: return .orange
        case .failed: return .red
        case .stopped: return .gray
        }
    }

    private var statusText: String {
        switch status {
        case .running:
            if let started = manager.runtime(for: service.id).startedAt {
                return "custom.service.status.running".localized() + " · " + Self.uptime(since: started)
            }
            return "custom.service.status.running".localized()
        case .starting: return "custom.service.status.starting".localized()
        case .stopping: return "custom.service.status.stopping".localized()
        case .stopped: return "custom.service.status.stopped".localized()
        case .failed(let message): return message
        }
    }

    private static func uptime(since date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h \((seconds % 3600) / 60)m"
    }
}

// MARK: - GitHub Token Sheet

/// Lets the user store a GitHub personal access token (in the Keychain) so
/// update checks use the authenticated rate limit (5000/hour vs 60/hour).
private struct GitHubTokenSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var token: String = KeychainHelper.getGitHubToken() ?? ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "key.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("custom.service.update.githubToken".localized())
                        .font(.headline)
                    Text("custom.service.update.githubToken.help".localized())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SecureField("ghp_…", text: $token)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            HStack {
                Button("custom.service.update.githubToken.clear".localized(), role: .destructive) {
                    KeychainHelper.deleteGitHubToken()
                    token = ""
                    dismiss()
                }
                .disabled(KeychainHelper.getGitHubToken() == nil)

                Spacer()

                Button("action.cancel".localized()) {
                    dismiss()
                }
                Button("action.save".localized()) {
                    let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        KeychainHelper.deleteGitHubToken()
                    } else {
                        KeychainHelper.saveGitHubToken(trimmed)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 480)
    }
}
