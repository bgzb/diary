import SwiftUI

struct SidebarView: View {
    @Environment(ViewModel.self) private var model
    @Environment(SettingsStore.self) private var settings
    @Environment(LockManager.self) private var lockManager
    @Binding var showCalendar: Bool
    @Binding var showCalendarStandalone: Bool

    @State private var groupsExpanded = false
    @State private var showNewGroupField = false
    @State private var newGroupName = ""
    @State private var renamingGroupID: String?
    @State private var renamingGroupText = ""
    @FocusState private var groupFieldFocused: Bool

    @State private var renamingEntryID: String?
    @State private var renameText: String = ""
    @FocusState private var renameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
                .padding(.horizontal, 10)
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

            Divider()
                .padding(.horizontal, 10)
                .padding(.top, 4)

            calendarSidebarButton
        }
        .background(sidebarBackground.ignoresSafeArea())
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
            TextField(L.string(.searchPlaceholder, lang: settings.appLanguage), text: Binding(
                get: { model.searchText },
                set: { model.searchText = $0 }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            if !model.searchText.isEmpty {
                Menu {
                    ForEach(SearchMode.allCases, id: \.self) { mode in
                        Button {
                            model.searchMode = mode
                        } label: {
                            HStack {
                                Text(mode.displayName(settings.appLanguage))
                                if model.searchMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text(model.searchMode.displayName(settings.appLanguage))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Button {
                    model.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Group Banner

    private var currentGroupName: String {
        model.groups.first(where: { $0.id == model.currentGroupID })?.name ?? "Diary"
    }

    private var groupBanner: some View {
        VStack(spacing: 0) {
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
                    if let group = model.groups.first(where: { $0.id == model.currentGroupID }),
                       model.isGroupLocked(group) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
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

            if groupsExpanded {
                VStack(spacing: 1) {
                    ForEach(model.groups) { group in
                        groupRow(group)
                    }

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
                if model.isGroupLocked(group) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
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
                model.toggleGroupLock(group)
            } label: {
                Label(model.isGroupLocked(group)
                      ? L.string(.unlockGroup, lang: settings.appLanguage)
                      : L.string(.lockGroup, lang: settings.appLanguage),
                      systemImage: model.isGroupLocked(group) ? "lock.open" : "lock")
            }
            Divider()
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
            Text(model.isSearchActive
                 ? L.string(.searchResults(model.totalSearchResultCount), lang: settings.appLanguage)
                 : currentGroupName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
            Spacer()
            if !model.isSearchActive {
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
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var entriesList: some View {
        if model.isSearchActive {
            searchResultsList
        } else if isCurrentGroupLocked {
            lockedGroupSidebarHint
        } else {
            normalEntriesList
        }
    }

    private var isCurrentGroupLocked: Bool {
        if let group = model.groups.first(where: { $0.id == model.currentGroupID }) {
            return model.isGroupLocked(group) && !lockManager.isGroupUnlocked(group.id)
        }
        return false
    }

    private var lockedGroupSidebarHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 20, weight: .ultraLight))
                .foregroundStyle(.tertiary)
            Text(L.string(.groupLocked, lang: settings.appLanguage))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 40)
    }

    private var searchResultsList: some View {
        List {
            ForEach(model.searchResults) { group in
                Section {
                    ForEach(group.entries) { result in
                        searchResultRow(result, groupName: group.groupName)
                    }
                } header: {
                    Text(group.groupName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    private func searchResultRow(_ result: SearchResultEntry, groupName: String) -> some View {
        let entry = result.entry
        let selected = entry.id == model.currentEntry?.id

        return Button {
            showCalendarStandalone = false
            model.selectSearchResult(entry)
        } label: {
            HStack(spacing: 6) {
                if model.isPinned(entry) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                }
                if model.isEntryLocked(entry) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Text(entry.title)
                    .lineLimit(1)
                    .font(.system(size: 13, weight: selected ? .medium : .regular))
                    .foregroundStyle(selected ? .primary : .secondary)
                Spacer()
                if model.searchMode == .content && result.matchCount > 0 {
                    Text("×\(result.matchCount)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(selected ? sidebarTint : Color.clear)
        .contextMenu {
            Button {
                model.selectEntry(entry)
                model.togglePin(entry)
            } label: {
                Label(model.isPinned(entry)
                      ? L.string(.unpinEntry, lang: settings.appLanguage)
                      : L.string(.pinEntry, lang: settings.appLanguage),
                      systemImage: model.isPinned(entry) ? "star.slash" : "star")
            }
            Divider()
            Button {
                model.selectEntry(entry)
                model.toggleEntryLock(entry)
            } label: {
                Label(model.isEntryLocked(entry)
                      ? L.string(.unlockEntry, lang: settings.appLanguage)
                      : L.string(.lockEntry, lang: settings.appLanguage),
                      systemImage: model.isEntryLocked(entry) ? "lock.open" : "lock")
            }
            Divider()
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

    private var normalEntriesList: some View {
        List(selection: Binding(
            get: { model.currentEntry?.id },
            set: { id in
                if let id, let entry = model.entries.first(where: { $0.id == id }) {
                    showCalendarStandalone = false
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
                        if model.isPinned(entry) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.yellow)
                                .padding(.trailing, 3)
                        }
                        if model.isEntryLocked(entry) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .padding(.trailing, 3)
                        }
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
                        model.togglePin(entry)
                    } label: {
                        Label(model.isPinned(entry)
                              ? L.string(.unpinEntry, lang: settings.appLanguage)
                              : L.string(.pinEntry, lang: settings.appLanguage),
                              systemImage: model.isPinned(entry) ? "star.slash" : "star")
                    }
                    Divider()
                    Button {
                        model.selectEntry(entry)
                        model.toggleEntryLock(entry)
                    } label: {
                        Label(model.isEntryLocked(entry)
                              ? L.string(.unlockEntry, lang: settings.appLanguage)
                              : L.string(.lockEntry, lang: settings.appLanguage),
                              systemImage: model.isEntryLocked(entry) ? "lock.open" : "lock")
                    }
                    Divider()
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

    // MARK: - Calendar Sidebar Button

    private var calendarSidebarButton: some View {
        Button {
            if showCalendar {
                showCalendar = false
            }
            showCalendarStandalone.toggle()
            model.selectedDate = showCalendarStandalone ? Date() : nil
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(showCalendarStandalone ? Color.accentColor : .secondary)
                Text(L.string(.calendar, lang: settings.appLanguage))
                    .font(.system(size: 13, weight: showCalendarStandalone ? .medium : .regular))
                    .foregroundStyle(showCalendarStandalone ? .primary : .secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(showCalendarStandalone ? Color.accentColor.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 6)
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

    // MARK: - Theme

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
}
