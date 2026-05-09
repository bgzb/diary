import SwiftUI

struct ContentView: View {
    @Environment(ViewModel.self) private var model
    @Environment(SettingsStore.self) private var settings
    @Environment(\.openSettings) private var openSettings

    @State private var renamingEntryID: String?
    @State private var renameText: String = ""
    @FocusState private var renameFocused: Bool

    @State private var groupsExpanded = false
    @State private var showNewGroupField = false
    @State private var newGroupName = ""
    @State private var renamingGroupID: String?
    @State private var renamingGroupText = ""
    @FocusState private var groupFieldFocused: Bool

    @State private var newEntryDialogName = ""

    var body: some View {
        // Track all settings that MarkdownEditorView depends on.
        // Without these reads, SwiftUI won't call updateNSView when settings change.
        let _ = settings.previewTheme
        let _ = settings.editorFontSize
        let _ = settings.editorFont
        let _ = settings.editorLineSpacing
        let _ = settings.editorSpellCheck
        let _ = settings.editorTabWidth

        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            mainContent
        }
        .preferredColorScheme(colorScheme)
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
        .alert(L.string(.newEntry, lang: settings.appLanguage), isPresented: Binding(
            get: { model.showNewEntryDialog },
            set: { model.showNewEntryDialog = $0 }
        )) {
            TextField(L.string(.entryName, lang: settings.appLanguage), text: $newEntryDialogName)
            Button(L.string(.create, lang: settings.appLanguage)) {
                model.createEntry(name: newEntryDialogName)
            }
            Button(L.string(.cancel, lang: settings.appLanguage), role: .cancel) {
                newEntryDialogName = ""
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

                Spacer()

                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .help(L.string(.settings, lang: settings.appLanguage))
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            groupBanner
            Divider()
                .padding(.horizontal, 10)
            VStack(spacing: 0) {
                entriesHeader
                entriesList
            }
            .contextMenu {
                Button {
                    model.newEntry()
                } label: {
                    Label(L.string(.newEntry, lang: settings.appLanguage),
                          systemImage: "square.and.pencil")
                }
            }
        }
        .background(sidebarBackground.ignoresSafeArea())
    }

    // MARK: - Group Banner

    private var currentGroupName: String {
        model.groups.first(where: { $0.id == model.currentGroupID })?.name ?? "Diary"
    }

    private var groupBanner: some View {
        VStack(spacing: 0) {
            // Collapse/expand toggle
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    groupsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: groupsExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 6, height: 6)
                    Text(currentGroupName)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    if groupsExpanded {
                        Button {
                            showNewGroupField = true
                            newGroupName = ""
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(L.string(.newGroup, lang: settings.appLanguage))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Group list when expanded
            if groupsExpanded {
                VStack(spacing: 1) {
                    ForEach(model.groups) { group in
                        groupRow(group)
                    }

                    // New group field
                    if showNewGroupField {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                            TextField("Name", text: $newGroupName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .focused($groupFieldFocused)
                                .onAppear { groupFieldFocused = true }
                                .onSubmit {
                                    let name = newGroupName.trimmingCharacters(in: .whitespaces)
                                    if !name.isEmpty {
                                        model.createGroup(name: name)
                                    }
                                    showNewGroupField = false
                                }
                                .onKeyPress(.escape) {
                                    showNewGroupField = false
                                    return .handled
                                }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func groupRow(_ group: DiaryGroup) -> some View {
        let isCurrent = group.id == model.currentGroupID
        return Button {
            model.selectGroup(group)
        } label: {
            HStack(spacing: 6) {
                if renamingGroupID == group.id {
                    TextField("", text: $renamingGroupText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .focused($groupFieldFocused)
                        .onAppear { groupFieldFocused = true }
                        .onSubmit {
                            commitGroupRename(group)
                        }
                        .onChange(of: groupFieldFocused) { _, focused in
                            if !focused { commitGroupRename(group) }
                        }
                        .onKeyPress(.escape) {
                            renamingGroupID = nil
                            return .handled
                        }
                } else {
                    Text(group.name)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .foregroundStyle(isCurrent ? .primary : .secondary)
                }
                Spacer()
                if isCurrent {
                    Circle()
                        .fill(Color.accentColor.opacity(0.4))
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
            .background(isCurrent ? Color.primary.opacity(0.06) : Color.clear)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                renamingGroupID = group.id
                renamingGroupText = group.name
            } label: {
                Label(L.string(.renameGroup, lang: settings.appLanguage),
                      systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                model.deleteGroup(group)
            } label: {
                Label(L.string(.deleteGroup, lang: settings.appLanguage),
                      systemImage: "trash")
            }
            .disabled(model.groups.count <= 1)
        }
    }

    // MARK: - Entries Section

    private var entriesHeader: some View {
        HStack {
            Text(currentGroupName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
            Spacer()
            Button {
                model.newEntry()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(L.string(.newEntry, lang: settings.appLanguage))
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var entriesList: some View {
        List(selection: Binding(
            get: { model.currentEntry?.id },
            set: { id in
                if let id, let entry = model.entries.first(where: { $0.id == id }) {
                    model.selectEntry(entry)
                }
            }
        )) {
            ForEach(model.entries) { entry in
                HStack(spacing: 0) {
                    if renamingEntryID == entry.id {
                        TextField("", text: $renameText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .focused($renameFocused)
                            .onAppear { renameFocused = true }
                            .onSubmit { commitEntryRename() }
                            .onChange(of: renameFocused) { _, focused in
                                if !focused { commitEntryRename() }
                            }
                            .onKeyPress(.escape) {
                                renamingEntryID = nil
                                return .handled
                            }
                    } else {
                        let selected = entry.id == model.currentEntry?.id
                        Text(entry.title)
                            .lineLimit(1)
                            .font(.system(size: 13, weight: selected ? .medium : .regular))
                            .foregroundStyle(selected ? .primary : .secondary)
                    }
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .tag(entry.id)
                .listRowBackground(
                    entry.id == model.currentEntry?.id
                        ? sidebarTint
                        : Color.clear
                )
                .contextMenu {
                    Button {
                        model.selectEntry(entry)
                        renamingEntryID = entry.id
                        renameText = entry.title
                    } label: {
                        Label(L.string(.rename, lang: settings.appLanguage),
                              systemImage: "pencil")
                    }
                    Divider()
                    Button {
                        model.newEntry()
                    } label: {
                        Label(L.string(.newEntry, lang: settings.appLanguage),
                              systemImage: "square.and.pencil")
                    }
                    Divider()
                    Button(role: .destructive) {
                        model.selectEntry(entry)
                        model.pendingDelete = true
                    } label: {
                        Label(L.string(.delete, lang: settings.appLanguage),
                              systemImage: "trash")
                    }
                }
            }
        }
        .onKeyPress(.return) {
            if let entry = model.currentEntry, renamingEntryID == nil {
                renamingEntryID = entry.id
                renameText = entry.title
                return .handled
            }
            return .ignored
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Actions

    private func commitEntryRename() {
        let name = renameText.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            model.renameCurrentEntry(to: name)
        }
        renamingEntryID = nil
    }

    private func commitGroupRename(_ group: DiaryGroup) {
        let name = renamingGroupText.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            model.renameGroup(group, to: name)
        }
        renamingGroupID = nil
    }

    // MARK: - Main Content

    private var colorScheme: ColorScheme? {
        switch settings.previewTheme {
        case .system: return nil
        case .light, .grey: return .light
        case .dark: return .dark
        }
    }

    private var sidebarBackground: Color {
        switch settings.previewTheme {
        case .light:  return Color(white: 0.91)
        case .grey:   return Color(red: 0.89, green: 0.88, blue: 0.86)
        case .dark:   return Color(white: 0.12)
        case .system:
            if NSApp.effectiveAppearance.name == .darkAqua { return Color(white: 0.12) }
            return Color(white: 0.91)
        }
    }

    private var contentBackground: Color {
        switch settings.previewTheme {
        case .light:  return Color(white: 0.98)
        case .grey:   return Color(red: 0.935, green: 0.925, blue: 0.900)
        case .dark:   return Color(red: 0.157, green: 0.153, blue: 0.145)
        case .system:
            if NSApp.effectiveAppearance.name == .darkAqua { return Color(red: 0.157, green: 0.153, blue: 0.145) }
            return Color(white: 0.98)
        }
    }

    private var sidebarTint: Color {
        switch settings.previewTheme {
        case .light:
            return Color(red: 0.80, green: 0.83, blue: 0.87)
        case .grey:
            return Color(red: 0.76, green: 0.74, blue: 0.70)
        case .dark:
            return Color(white: 0.28)
        case .system:
            if NSApp.effectiveAppearance.name == .darkAqua {
                return Color(white: 0.28)
            }
            return Color(red: 0.80, green: 0.83, blue: 0.87)
        }
    }

    private var editorID: String {
        "\(settings.previewTheme.rawValue)-\(settings.editorFontSize)-\(settings.editorFont.rawValue)-\(settings.editorLineSpacing)-\(settings.editorSpellCheck)-\(settings.editorTabWidth)"
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            if let entry = model.currentEntry {
                Text(entry.title)
                    .font(.system(size: 28, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(height: 1)
                MarkdownEditorView(
                    text: Binding(get: { model.editorText }, set: { model.editorText = $0 }),
                    settings: settings
                )
                .id(editorID)
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
}
