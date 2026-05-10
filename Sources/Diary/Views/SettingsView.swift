import SwiftUI
import AppKit

struct SettingsView: View {
    let viewModel: ViewModel
    @Bindable var settings: SettingsStore

    private var l: (LKey) -> String { { L.string($0, lang: settings.appLanguage) } }

    var body: some View {
        TabView {
            storageTab
                .tabItem { Label(l(.tabStorage), systemImage: "folder") }
            editorTab
                .tabItem { Label(l(.tabEditor), systemImage: "text.alignleft") }
            previewTab
                .tabItem { Label(l(.tabPreview), systemImage: "eye") }
            generalTab
                .tabItem { Label(l(.tabGeneral), systemImage: "gearshape") }
            shortcutsTab
                .tabItem { Label(l(.tabShortcuts), systemImage: "command") }
        }
        .id(settings.appLanguage)
    }

    // MARK: - Storage

    private var storageTab: some View {
        Form {
            Section {
                HStack {
                    TextField("Path", text: $settings.storagePath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Button(l(.browse)) {
                        browseStoragePath()
                    }
                }
                Text("\(l(.entriesDirectory)) \(settings.resolvedStoragePath)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text(l(.storageLocation))
            }

            Section {
                Toggle(l(.datePrefix), isOn: $settings.useDatePrefix)
                Button(l(.reloadDisk)) {
                    viewModel.reloadStorage()
                }
            } header: {
                Text(l(.fileNaming))
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Editor

    private var editorTab: some View {
        Form {
            Section {
                Picker(l(.font_), selection: $settings.editorFont) {
                    ForEach(EditorFont.allCases, id: \.self) { font in
                        Text(font.displayName(settings.appLanguage)).tag(font)
                    }
                }
                LabeledContent(l(.fontSize)) {
                    IntField(value: $settings.editorFontSize, range: 10...28)
                        .frame(width: 64)
                }
            } header: {
                Text(l(.font_))
            }

            Section {
                LabeledContent(l(.lineSpacing)) {
                    IntField(value: $settings.editorLineSpacing, range: 0...12)
                        .frame(width: 64)
                }
                Picker(l(.tabWidth), selection: $settings.editorTabWidth) {
                    Text("2").tag(2)
                    Text("4").tag(4)
                    Text("8").tag(8)
                }
            } header: {
                Text(l(.layout))
            }

            Section {
                Toggle(l(.spellCheck), isOn: $settings.editorSpellCheck)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Preview

    private var previewTab: some View {
        Form {
            Section {
                Picker(l(.theme), selection: $settings.previewTheme) {
                    ForEach(PreviewTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName(settings.appLanguage)).tag(theme)
                    }
                }
            } header: {
                Text(l(.appearance))
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section {
                Toggle(l(.openLastEntry), isOn: $settings.openLastEntry)
            } header: {
                Text(l(.startup))
            }

            Section {
                Picker(l(.autoSaveDelay), selection: $settings.autoSaveInterval) {
                    Text(l(.autoSave05s)).tag(0.5)
                    Text(l(.autoSave1s)).tag(1.0)
                    Text(l(.autoSave2s)).tag(2.0)
                    Text(l(.autoSave5s)).tag(5.0)
                }
            } header: {
                Text(l(.saving))
            }

            Section {
                Picker(l(.language),
                       selection: $settings.appLanguage) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName(settings.appLanguage)).tag(lang)
                    }
                }
            } header: {
                Text(l(.language))
            }

            Section {
                Button(l(.resetDefaults)) {
                    resetDefaults()
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Shortcuts

    private var shortcutsTab: some View {
        Form {
            Section {
                ShortcutRow(keys: "⌘ N", label: l(.newEntry), desc: l(.shortcutNewEntryDesc))
                Divider()
                ShortcutRow(keys: "⌘ S", label: l(.save), desc: l(.shortcutSaveDesc))
                Divider()
                ShortcutRow(keys: "⌘ ⌫", label: l(.deleteEntry), desc: l(.shortcutDeleteEntryDesc))
                Divider()
                ShortcutRow(keys: "⌘ ,", label: l(.settings), desc: l(.shortcutSettingsDesc))
            } header: {
                Text(l(.shortcutSection))
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Actions

    private func browseStoragePath() {
        let panel = NSOpenPanel()
        panel.title = l(.selectFolder)
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: settings.resolvedStoragePath)

        if panel.runModal() == .OK, let url = panel.url {
            settings.storagePath = url.path
            viewModel.reloadStorage()
        }
    }

    private func resetDefaults() {
        settings.storagePath = settings.defaultStoragePath
        settings.useDatePrefix = false
        settings.editorFontSize = 14
        settings.editorFont = .systemMonospaced
        settings.editorLineSpacing = 4
        settings.editorSpellCheck = false
        settings.editorTabWidth = 4
        settings.previewTheme = .system
        settings.openLastEntry = true
        settings.autoSaveInterval = 1.0
        settings.appLanguage = .system
        viewModel.reloadStorage()
    }
}

private struct ShortcutRow: View {
    let keys: String
    let label: String
    let desc: String

    var body: some View {
        HStack(spacing: 12) {
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(minWidth: 56, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13))
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Integer text field bound to a Double, clamped to a range.
private struct IntField: View {
    @Binding var value: Double
    let range: ClosedRange<Int>

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
            .focused($isFocused)
            .onAppear { text = "\(Int(value))" }
            .onChange(of: value) { _, _ in
                if !isFocused { text = "\(Int(value))" }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
            .onSubmit { commit() }
    }

    private func commit() {
        if let intVal = Int(text), range.contains(intVal) {
            value = Double(intVal)
        } else {
            // Clamp and reset
            let clamped = Int(value)
            text = "\(clamped)"
        }
    }
}
