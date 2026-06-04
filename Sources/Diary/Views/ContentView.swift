import SwiftUI

struct ContentView: View {
    @Environment(ViewModel.self) private var model
    @Environment(SettingsStore.self) private var settings
    @Environment(LockManager.self) private var lockManager
    @Environment(\.openSettings) private var openSettings

    @State private var newEntryDialogName = ""
    @State private var unlockPassword = ""
    @State private var unlockError: String?
    @State private var groupUnlockPassword = ""
    @State private var groupUnlockError: String?
    @State private var showCalendar = false
    @State private var showCalendarStandalone = false

    var body: some View {
        // Track all settings that MarkdownEditorView depends on.
        // Without these reads, SwiftUI won't call updateNSView when settings change.
        let _ = settings.previewTheme
        let _ = settings.editorFontSize
        let _ = settings.editorFont
        let _ = settings.editorLineSpacing
        let _ = settings.editorSpellCheck
        let _ = settings.editorTabWidth
        let _ = lockManager.contentUnlocked
        let _ = lockManager.unlockedGroupIDs
        let _ = model.lockVersion

        NavigationSplitView {
            SidebarView(
                showCalendar: $showCalendar,
                showCalendarStandalone: $showCalendarStandalone
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            mainContent
                .overlay(alignment: .trailing) {
                    if showCalendar {
                        calendarPanelOverlay
                            .transition(.move(edge: .trailing))
                    }
                }
        }
        .animation(.easeInOut(duration: 0.25), value: showCalendar)
        .alert(L.string(.deleteEntryTitle, lang: settings.appLanguage), isPresented: Binding(
            get: { model.pendingDelete },
            set: { model.pendingDelete = $0 }
        )) {
            Button(role: .cancel) {
                model.pendingDelete = false
            } label: {
                Text(L.string(.cancel, lang: settings.appLanguage))
            }
            Button(role: .destructive) {
                model.deleteCurrentEntry()
                model.pendingDelete = false
            } label: {
                Text(L.string(.delete, lang: settings.appLanguage))
            }
        } message: {
            Text(L.string(.deleteEntryMessage, lang: settings.appLanguage))
        }
        .sheet(isPresented: Binding(
            get: { model.showNewEntryDialog },
            set: { model.showNewEntryDialog = $0 }
        )) {
            newEntrySheet
        }
        .onChange(of: showCalendar) { _, visible in
            if !visible {
                model.selectedDate = nil
            }
        }
        .onChange(of: model.showNewEntryDialog) { _, showing in
            if showing {
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                newEntryDialogName = df.string(from: Date())
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.newEntry()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .help(L.string(.newEntry, lang: settings.appLanguage))

                Button {
                    if showCalendarStandalone {
                        showCalendarStandalone = false
                    }
                    showCalendar.toggle()
                    if showCalendar {
                        model.selectedDate = Date()
                    } else {
                        model.selectedDate = nil
                    }
                } label: {
                    Image(systemName: "calendar")
                }
                .keyboardShortcut(settings.shortcutConfig(for: ShortcutAction.calendar).keyEquivalent,
                                  modifiers: settings.shortcutConfig(for: ShortcutAction.calendar).eventModifiers)
                .help(L.string(.calendar, lang: settings.appLanguage))

                Spacer()

                if lockManager.isEnabled {
                    Button {
                        lockManager.lock()
                    } label: {
                        Image(systemName: "lock")
                    }
                    .help(L.string(.lockApp, lang: settings.appLanguage))
                }

                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .help(L.string(.settings, lang: settings.appLanguage))
            }
        }
    }

    // MARK: - Main Content

    private var contentBackground: Color {
        switch settings.previewTheme {
        case .light:  return Color(white: 0.98)
        case .grey:   return Color(red: 0.935, green: 0.925, blue: 0.900)
        case .dark:   return Color(red: 0.157, green: 0.153, blue: 0.145)
        case .custom: return settings.customThemeColors.contentBackground.color
        case .system:
            if NSApp.effectiveAppearance.name == .darkAqua { return Color(red: 0.157, green: 0.153, blue: 0.145) }
            return Color(white: 0.98)
        }
    }

    private var editorID: String {
        "\(settings.previewTheme.rawValue)-\(settings.editorFont.rawValue)"
    }

    private var isCurrentGroupLocked: Bool {
        if let group = model.groups.first(where: { $0.id == model.currentGroupID }) {
            return model.isGroupLocked(group) && !lockManager.isGroupUnlocked(group.id)
        }
        return false
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            if showCalendarStandalone {
                CalendarPanelView(
                    mode: .standalone,
                    showCalendarStandalone: $showCalendarStandalone
                )
            } else if isCurrentGroupLocked {
                groupLockedOverlay
            } else if let entry = model.currentEntry {
                if model.isEntryLocked(entry) && !lockManager.contentUnlocked {
                    lockedEntryOverlay
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.title)
                            .font(.system(size: 28, weight: .bold))
                        Spacer()
                        ClockView(appLanguage: settings.appLanguage)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                    Rectangle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(height: 1)
                    MarkdownEditorView(
                        text: Binding(get: { model.editorText }, set: { model.editorText = $0 }),
                        settings: settings,
                        groupDir: URL(fileURLWithPath: (settings.resolvedStoragePath as NSString).expandingTildeInPath)
                            .appendingPathComponent(model.currentGroupID)
                    )
                    .id(editorID)

                    Divider()
                        .padding(.horizontal, 20)
                    statusBar
                }
            } else {
                emptyState
            }
        }
        .background(contentBackground)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.pages")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(.tertiary)
            Text(L.string(.noEntries, lang: settings.appLanguage))
                .font(.title3)
                .foregroundStyle(.secondary)
            Button(L.string(.createFirstEntry, lang: settings.appLanguage)) {
                model.newEntry()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusBar: some View {
        HStack(spacing: 0) {
            Text("\(model.charCount) \(L.string(.characters, lang: settings.appLanguage))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(" · ")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("\(model.wordCount) \(L.string(.words, lang: settings.appLanguage))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                    .foregroundStyle(model.writingStreak > 0 ? Color.orange : Color.secondary)
                Text(L.string(.streakDays(model.writingStreak), lang: settings.appLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }

    // MARK: - Calendar Panel Overlay

    private var calendarPanelOverlay: some View {
        CalendarPanelView(
            mode: .inspector,
            showCalendarStandalone: $showCalendarStandalone
        )
        .frame(width: 280)
        .background(contentBackground)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(width: 1)
        }
    }

    // MARK: - New Entry Sheet

    private var newEntrySheet: some View {
        VStack(spacing: 16) {
            Text(L.string(.newEntry, lang: settings.appLanguage))
                .font(.title3)
                .fontWeight(.semibold)

            TextField(L.string(.entryName, lang: settings.appLanguage), text: $newEntryDialogName)
                .textFieldStyle(.roundedBorder)

            Toggle(isOn: Binding(
                get: { model.newEntryLocked },
                set: { model.newEntryLocked = $0 }
            )) {
                Label(L.string(.lockEntry, lang: settings.appLanguage),
                      systemImage: "lock")
            }
            .disabled(!lockManager.hasPassword)

            if !lockManager.hasPassword {
                Text(L.string(.lockEntryHint, lang: settings.appLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button(L.string(.cancel, lang: settings.appLanguage), role: .cancel) {
                    newEntryDialogName = ""
                    model.newEntryLocked = false
                    model.showNewEntryDialog = false
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button(L.string(.create, lang: settings.appLanguage)) {
                    model.createEntry(name: newEntryDialogName, lock: model.newEntryLocked)
                    newEntryDialogName = ""
                    model.newEntryLocked = false
                    model.showNewEntryDialog = false
                }
                .keyboardShortcut(.return)
                .disabled(newEntryDialogName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 340)
    }

    // MARK: - Group Locked Overlay

    private var groupLockedOverlay: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(.tertiary)

            Text(L.string(.groupLockedTitle, lang: settings.appLanguage))
                .font(.title3)
                .foregroundStyle(.secondary)

            SecureField(L.string(.enterPassword, lang: settings.appLanguage), text: $groupUnlockPassword)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)

            Button {
                attemptGroupUnlock()
            } label: {
                Label(L.string(.unlock, lang: settings.appLanguage), systemImage: "lock.open")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(groupUnlockPassword.isEmpty)

            if let error = groupUnlockError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func attemptGroupUnlock() {
        guard let group = model.groups.first(where: { $0.id == model.currentGroupID }) else { return }
        if lockManager.unlockGroup(group.id, with: groupUnlockPassword) {
            groupUnlockPassword = ""
            groupUnlockError = nil
        } else {
            groupUnlockError = L.string(.incorrectPassword, lang: settings.appLanguage)
            groupUnlockPassword = ""
        }
    }

    // MARK: - Locked Entry Overlay

    private var lockedEntryOverlay: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(.tertiary)

            Text(L.string(.entryLocked, lang: settings.appLanguage))
                .font(.title3)
                .foregroundStyle(.secondary)

            SecureField(L.string(.enterPassword, lang: settings.appLanguage), text: $unlockPassword)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)

            Button {
                attemptContentUnlock()
            } label: {
                Label(L.string(.unlock, lang: settings.appLanguage), systemImage: "lock.open")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(unlockPassword.isEmpty)

            if let error = unlockError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func attemptContentUnlock() {
        if lockManager.unlockContent(with: unlockPassword) {
            unlockPassword = ""
            unlockError = nil
        } else {
            unlockError = L.string(.incorrectPassword, lang: settings.appLanguage)
            unlockPassword = ""
        }
    }
}
