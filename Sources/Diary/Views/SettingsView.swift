import SwiftUI
import AppKit

struct SettingsView: View {
    let viewModel: ViewModel
    @Bindable var settings: SettingsStore
    @Environment(LockManager.self) private var lockManager
    @State private var passwordSheetMode: PasswordMode?
    @State private var recordingAction: String?
    @State private var keyMonitor: Any?
    private var l: (LKey) -> String { { L.string($0, lang: settings.appLanguage) } }

    private var isGrey: Bool { settings.previewTheme == .grey }

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label(l(.tabGeneral), systemImage: "gearshape") }
                .formBackgroundGrey(isGrey)
            editorTab
                .tabItem { Label(l(.tabEditor), systemImage: "text.alignleft") }
                .formBackgroundGrey(isGrey)
            shortcutsTab
                .tabItem { Label(l(.tabShortcuts), systemImage: "command") }
                .formBackgroundGrey(isGrey)
        }
        .id(settings.appLanguage)
        .background(GreyWindowTinter(isGrey: isGrey))
        .onChange(of: recordingAction) { _, newValue in
            if newValue != nil {
                installKeyMonitor()
            } else {
                removeKeyMonitor()
            }
        }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section {
                Picker(l(.theme), selection: $settings.previewTheme) {
                    ForEach(PreviewTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName(settings.appLanguage)).tag(theme)
                    }
                }
                Picker(l(.language), selection: $settings.appLanguage) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName(settings.appLanguage)).tag(lang)
                    }
                }
            } header: {
                Label(l(.appearanceSection), systemImage: "paintpalette")
            }

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
                Toggle(l(.datePrefix), isOn: $settings.useDatePrefix)
                Button(l(.reloadDisk)) {
                    viewModel.reloadStorage()
                }
            } header: {
                Label(l(.storageLocation), systemImage: "folder")
            }

            Section {
                Toggle(l(.openLastEntry), isOn: $settings.openLastEntry)
                Picker(l(.autoSaveDelay), selection: $settings.autoSaveInterval) {
                    Text(l(.autoSave05s)).tag(0.5)
                    Text(l(.autoSave1s)).tag(1.0)
                    Text(l(.autoSave2s)).tag(2.0)
                    Text(l(.autoSave5s)).tag(5.0)
                }
            } header: {
                Label(l(.behavior), systemImage: "switch.2")
            }

            Section {
                Toggle(l(.reminderEnabled), isOn: $settings.reminderEnabled)

                if settings.reminderEnabled {
                    LabeledContent(l(.reminderTime)) {
                        Button {
                            showReminderTimeWindow()
                        } label: {
                            Text(String(format: "%02d:%02d", settings.reminderHour, settings.reminderMinute))
                                .monospacedDigit()
                                .frame(width: 48, alignment: .trailing)
                        }
                    }
                }
            } header: {
                Label(l(.dailyReminder), systemImage: "bell")
            }

            Section {
                if lockManager.isEnabled {
                    Button(l(.changePassword)) {
                        passwordSheetMode = .change
                    }
                    Button(l(.turnOffPassword), role: .destructive) {
                        passwordSheetMode = .turnOff
                    }
                } else {
                    Button(l(.setPassword)) {
                        passwordSheetMode = .set
                    }
                }
            } header: {
                Label(l(.password), systemImage: "lock")
            }

            Section {
                Button(l(.resetDefaults)) {
                    resetDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .sheet(item: $passwordSheetMode) { mode in
            SetPasswordView(mode: mode)
                .environment(lockManager)
                .environment(settings)
        }
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
                Label(l(.font_), systemImage: "character.textbox")
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
                Label(l(.layout), systemImage: "text.alignleft")
            }

            Section {
                Toggle(l(.spellCheck), isOn: $settings.editorSpellCheck)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Shortcuts

    private var shortcutsTab: some View {
        Form {
            Section {
                ForEach(ShortcutAction.all, id: \.id) { action in
                    ShortcutRebindRow(
                        label: shortcutLabel(for: action.id),
                        config: shortcutBinding(for: action.id),
                        isRecording: recordingAction == action.id,
                        onTap: { recordingAction = action.id },
                        onReset: {
                            settings.shortcuts[action.id] = settings.defaultShortcut(for: action.id)
                        }
                    )
                    if action.id != ShortcutAction.all.last?.id {
                        Divider()
                    }
                }
                HStack {
                    Spacer()
                    Button(l(.shortcutResetAll)) {
                        settings.resetShortcuts()
                    }
                    .font(.caption)
                }
            } header: {
                Label(l(.shortcutSection), systemImage: "command")
            }
        }
        .formStyle(.grouped)
        .overlay {
            if recordingAction != nil {
                recordingOverlay
            }
        }
    }

    private var recordingOverlay: some View {
        VStack(spacing: 12) {
            Text(l(.shortcutRecording))
                .font(.title3)
                .fontWeight(.medium)
            Text("Esc")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.secondary.opacity(0.15)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }

    private func shortcutLabel(for action: String) -> String {
        switch action {
        case ShortcutAction.newEntry: return l(.shortcutActionNewEntry)
        case ShortcutAction.save: return l(.shortcutActionSave)
        case ShortcutAction.deleteEntry: return l(.shortcutActionDelete)
        case ShortcutAction.export: return l(.shortcutActionExport)
        case ShortcutAction.calendar: return l(.shortcutActionCalendar)
        default: return action
        }
    }

    private func shortcutBinding(for action: String) -> Binding<ShortcutConfig> {
        Binding(
            get: { settings.shortcutConfig(for: action) },
            set: { settings.shortcuts[action] = $0 }
        )
    }

    // MARK: - Key Monitor

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard recordingAction != nil else { return event }

            if event.keyCode == 53 { // Escape
                DispatchQueue.main.async { recordingAction = nil }
                return nil
            }

            let chars = event.charactersIgnoringModifiers ?? ""
            guard let firstChar = chars.first else { return nil }

            var mods: NSEvent.ModifierFlags = []
            if event.modifierFlags.contains(.command) { mods.insert(.command) }
            if event.modifierFlags.contains(.option) { mods.insert(.option) }
            if event.modifierFlags.contains(.control) { mods.insert(.control) }
            if event.modifierFlags.contains(.shift) { mods.insert(.shift) }

            // Skip if only modifiers (no actual key)
            let modifierOnlyKeys: Set<UInt16> = Set([54, 55, 56, 57, 58, 59, 60, 61, 62, 63])
            if modifierOnlyKeys.contains(event.keyCode) { return nil }

            let swiftUIMods = EventModifiers(rawValue: Int(mods.rawValue))

            DispatchQueue.main.async {
                if let action = recordingAction {
                    settings.shortcuts[action] = ShortcutConfig(
                        key: String(firstChar),
                        modifiers: Int(swiftUIMods.rawValue)
                    )
                }
                recordingAction = nil
            }
            return nil
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    // MARK: - Actions

    private func showReminderTimeWindow() {
        let isChinese = settings.appLanguage.resolved == .chinese
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 360),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = isChinese ? "选择时间" : "Select Time"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        window.isReleasedWhenClosed = false

        window.contentView = NSHostingView(rootView: ReminderTimePickerView(
            hour: $settings.reminderHour,
            minute: $settings.reminderMinute,
            language: settings.appLanguage,
            onDismiss: { [weak window] in
                window?.close()
            }
        ))

        window.makeKeyAndOrderFront(nil)
    }

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
        settings.reminderEnabled = false
        settings.reminderHour = 20
        settings.reminderMinute = 0
        settings.resetShortcuts()
        viewModel.reloadStorage()
    }
}

// MARK: - Shortcut Rebind Row

private struct ShortcutRebindRow: View {
    let label: String
    @Binding var config: ShortcutConfig
    let isRecording: Bool
    let onTap: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 13))

            Spacer()

            if isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 6, height: 6)
                    Text("Recording…")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.red.opacity(0.1)))
            } else {
                Button {
                    onTap()
                } label: {
                    Text(config.displayString)
                        .font(.system(size: 12, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }

            Button {
                onReset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isRecording ? 0 : 1)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - ShortcutRow (legacy read-only, kept for reference)

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

// MARK: - Grey Theme Window Background

private struct GreyWindowTinter: NSViewRepresentable {
    let isGrey: Bool

    func makeNSView(context: Context) -> WindowTintView {
        let view = WindowTintView()
        view.isGrey = isGrey
        return view
    }

    func updateNSView(_ nsView: WindowTintView, context: Context) {
        nsView.isGrey = isGrey
        if let w = nsView.window { w.tintGrey(isGrey) }
    }
}

private final class WindowTintView: NSView {
    var isGrey = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.tintGrey(isGrey)
    }
}

private extension NSWindow {
    func tintGrey(_ grey: Bool) {
        if grey {
            titlebarAppearsTransparent = true
            backgroundColor = NSColor(red: 0.935, green: 0.925, blue: 0.900, alpha: 1.0)
            if let content = contentView {
                styleMask.insert(.fullSizeContentView)
                tintEffectViews(content, grey: true)
            }
        } else {
            titlebarAppearsTransparent = false
            backgroundColor = NSColor.windowBackgroundColor
            if let content = contentView {
                styleMask.remove(.fullSizeContentView)
                tintEffectViews(content, grey: false)
            }
        }
    }
}

private func tintEffectViews(_ view: NSView, grey: Bool) {
    if let effect = view as? NSVisualEffectView {
        effect.material = grey ? .windowBackground : .sidebar
    }
    for sub in view.subviews { tintEffectViews(sub, grey: grey) }
}

// MARK: - Grey Theme Form Background

private extension View {
    func formBackgroundGrey(_ isGrey: Bool) -> some View {
        self
            .scrollContentBackground(isGrey ? .hidden : .visible)
            .background(
                isGrey
                    ? Color(red: 0.935, green: 0.925, blue: 0.900)
                    : .clear
            )
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
            let clamped = Int(value)
            text = "\(clamped)"
        }
    }
}
