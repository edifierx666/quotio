//
//  CustomServiceLogViewer.swift
//  Quotio
//
//  Live log viewer for a custom service.
//

import SwiftUI
import AppKit

struct CustomServiceLogViewer: View {
    @Environment(\.dismiss) private var dismiss

    let service: CustomService

    @State private var manager = CustomServiceManager.shared
    @State private var autoScroll = true

    private var logStore: CustomServiceLogStore {
        manager.logStore(for: service.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            logContent
            Divider()
            footer
        }
        .frame(width: 720, height: 520)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                    .font(.headline)
                Text(service.command)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: - Log Content

    private var logContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(logStore.lines) { line in
                        Text(line.text)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(line.isError ? Color.red : Color.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                }
                .padding(12)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .overlay {
                if logStore.lines.isEmpty {
                    Text("custom.service.log.empty".localized())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: logStore.lines.count) {
                guard autoScroll, let last = logStore.lines.last else { return }
                withAnimation(.linear(duration: 0.1)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
            .onAppear {
                if let last = logStore.lines.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Toggle("custom.service.log.autoScroll".localized(), isOn: $autoScroll)
                .toggleStyle(.checkbox)

            Spacer()

            Text(String(format: "custom.service.log.lineCount".localized(), logStore.lines.count))
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                copyLogs()
            } label: {
                Label("action.copy".localized(), systemImage: "doc.on.doc")
            }
            .disabled(logStore.lines.isEmpty)

            Button {
                manager.clearLogs(for: service.id)
            } label: {
                Label("custom.service.log.clear".localized(), systemImage: "trash")
            }
            .disabled(logStore.lines.isEmpty)
        }
        .padding(16)
    }

    private var statusColor: Color {
        switch manager.status(for: service.id) {
        case .running: return .green
        case .starting, .stopping: return .orange
        case .failed: return .red
        case .stopped: return .gray
        }
    }

    private func copyLogs() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logStore.combinedText, forType: .string)
    }
}
