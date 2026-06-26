//
//  CustomServiceEditorSheet.swift
//  Edx
//
//  Add / edit a custom long-running service.
//

import SwiftUI
import AppKit

struct CustomServiceEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let service: CustomService?
    let onSave: (CustomService) -> Void

    @State private var name: String
    @State private var command: String
    @State private var workingDirectory: String
    @State private var showInMenuBar: Bool
    @State private var autoStart: Bool
    @State private var envEntries: [EnvEntry]

    init(service: CustomService?, onSave: @escaping (CustomService) -> Void) {
        self.service = service
        self.onSave = onSave

        if let service {
            _name = State(initialValue: service.name)
            _command = State(initialValue: service.command)
            _workingDirectory = State(initialValue: service.workingDirectory ?? "")
            _showInMenuBar = State(initialValue: service.showInMenuBar)
            _autoStart = State(initialValue: service.autoStart)
            _envEntries = State(
                initialValue: service.environment
                    .sorted { $0.key < $1.key }
                    .map { EnvEntry(key: $0.key, value: $0.value) }
            )
        } else {
            _name = State(initialValue: "")
            _command = State(initialValue: "")
            _workingDirectory = State(initialValue: "")
            _showInMenuBar = State(initialValue: true)
            _autoStart = State(initialValue: false)
            _envEntries = State(initialValue: [])
        }
    }

    private var isEditing: Bool { service != nil }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !command.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    basicSection
                    environmentSection
                    optionsSection
                }
                .padding(20)
            }

            Divider()
            footer
        }
        .frame(width: 720, height: 720)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: "terminal")
                .font(.title2)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(isEditing ? "custom.service.edit".localized() : "custom.service.add".localized())
                    .font(.headline)
                Text("custom.service.editor.subtitle".localized())
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .padding(20)
    }

    // MARK: - Basic Section

    private var basicSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("custom.service.editor.basic".localized())

            VStack(alignment: .leading, spacing: 4) {
                Text("custom.service.field.name".localized())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("custom.service.field.name.placeholder".localized(), text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("custom.service.field.command".localized())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $command)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(minHeight: 140, maxHeight: 240)
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay(alignment: .topLeading) {
                        if command.isEmpty {
                            Text("custom.service.field.command.placeholder".localized())
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 14)
                                .allowsHitTesting(false)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text("custom.service.field.command.help".localized())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("custom.service.field.workingDir".localized())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    TextField("custom.service.field.workingDir.placeholder".localized(), text: $workingDirectory)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Button("custom.service.field.workingDir.choose".localized()) {
                        chooseWorkingDirectory()
                    }
                }
            }
        }
    }

    // MARK: - Environment Section

    private var environmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("custom.service.editor.environment".localized())
                Spacer()
                Button {
                    envEntries.append(EnvEntry(key: "", value: ""))
                } label: {
                    Label("custom.service.env.add".localized(), systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            if envEntries.isEmpty {
                Text("custom.service.env.empty".localized())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach($envEntries) { $entry in
                    HStack(spacing: 8) {
                        TextField("KEY", text: $entry.key)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Text("=")
                            .foregroundStyle(.secondary)
                        TextField("value", text: $entry.value)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Button {
                            envEntries.removeAll { $0.id == entry.id }
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("custom.service.editor.options".localized())

            Toggle(isOn: $showInMenuBar) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("custom.service.option.showInMenuBar".localized())
                    Text("custom.service.option.showInMenuBar.help".localized())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $autoStart) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("custom.service.option.autoStart".localized())
                    Text("custom.service.option.autoStart.help".localized())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button("action.cancel".localized()) {
                dismiss()
            }
            Button(isEditing ? "action.save".localized() : "custom.service.add".localized()) {
                save()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isValid)
        }
        .padding(20)
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
    }

    private func save() {
        var environment: [String: String] = [:]
        for entry in envEntries {
            let key = entry.key.trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            environment[key] = entry.value
        }

        let trimmedDir = workingDirectory.trimmingCharacters(in: .whitespaces)

        let result = CustomService(
            id: service?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            command: command.trimmingCharacters(in: .whitespaces),
            workingDirectory: trimmedDir.isEmpty ? nil : trimmedDir,
            environment: environment,
            showInMenuBar: showInMenuBar,
            autoStart: autoStart
        )

        onSave(result)
        dismiss()
    }

    private func chooseWorkingDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            workingDirectory = url.path
        }
    }
}

// MARK: - Env Entry

private struct EnvEntry: Identifiable {
    let id = UUID()
    var key: String
    var value: String
}
