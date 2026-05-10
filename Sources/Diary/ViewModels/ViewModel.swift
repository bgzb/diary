import SwiftUI
import Observation

@Observable
final class ViewModel {
    var currentEntry: Entry? {
        didSet {
            editorText = currentEntry?.content ?? ""
            if let entry = currentEntry {
                UserDefaults.standard.set(entry.id, forKey: "diary_lastEntryID")
            }
        }
    }
    var editorText = "" {
        didSet {
            scheduleAutoSave()
        }
    }
    var entries: [Entry] { store.entries }
    var groups: [DiaryGroup] { store.groups }
    var currentGroupID: String { store.currentGroupID }

    var selectedDate: Date?
    var entryDates: Set<Date> {
        Set(store.allEntryDates().map { Calendar.current.startOfDay(for: $0) })
    }

    func entriesForSelectedDate() -> [(Entry, groupName: String)] {
        guard let date = selectedDate else { return [] }
        return store.entriesForDate(date)
    }

    let settings: SettingsStore
    var pendingDelete = false
    private var store: EntryStore
    private var saveTimer: Timer?
    private var lastSavedContent: String?

    init(settings: SettingsStore) {
        self.settings = settings
        self.store = EntryStore(
            basePath: settings.resolvedStoragePath,
            useDatePrefix: settings.useDatePrefix
        )

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.flushSave(force: true)
        }

        let lastID = UserDefaults.standard.string(forKey: "diary_lastEntryID")
        if settings.openLastEntry,
           let id = lastID,
           let last = store.entries.first(where: { $0.id == id }) {
            selectEntry(last)
        } else if let first = store.entries.first {
            selectEntry(first)
        }
    }

    // MARK: - Entries

    func selectEntry(_ entry: Entry) {
        flushSave()
        lastSavedContent = entry.content
        currentEntry = entry
    }

    var showNewEntryDialog = false

    func newEntry() {
        flushSave()
        showNewEntryDialog = true
    }

    func createEntry(name: String) {
        let title = name.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        store.useDatePrefix = settings.useDatePrefix
        let entry = store.createEntry(title: title)
        selectEntry(entry)
    }

    func saveCurrentEntry() {
        flushSave(force: true)
    }

    func renameCurrentEntry(to newTitle: String) {
        guard let entry = currentEntry else { return }
        flushSave()
        if let updated = store.renameEntry(entry, to: newTitle) {
            currentEntry = updated
        }
    }

    func deleteCurrentEntry() {
        guard let entry = currentEntry else { return }
        store.deleteEntry(entry)
        currentEntry = store.entries.first
    }

    func reloadStorage() {
        flushSave()
        store.reload(basePath: settings.resolvedStoragePath)
        if let first = store.entries.first {
            selectEntry(first)
        } else {
            currentEntry = nil
        }
    }

    // MARK: - Groups

    func selectGroup(_ group: DiaryGroup) {
        flushSave()
        store.selectGroup(group)
        if let first = store.entries.first {
            selectEntry(first)
        } else {
            currentEntry = nil
        }
    }

    func createGroup(name: String) {
        flushSave()
        let group = store.createGroup(name: name)
        store.selectGroup(group)
        if let first = store.entries.first {
            selectEntry(first)
        } else {
            currentEntry = nil
        }
    }

    func renameGroup(_ group: DiaryGroup, to newName: String) {
        store.renameGroup(group, to: newName)
    }

    func deleteGroup(_ group: DiaryGroup) {
        store.deleteGroup(group)
        if currentEntry == nil || !store.entries.contains(where: { $0.id == currentEntry?.id }) {
            currentEntry = store.entries.first
        }
    }

    func reorderGroups(from source: IndexSet, to destination: Int) {
        store.reorderGroups(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Auto-save

    private func scheduleAutoSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(
            withTimeInterval: settings.autoSaveInterval,
            repeats: false
        ) { [weak self] _ in
            self?.flushSave()
        }
    }

    private func flushSave(force: Bool = false) {
        saveTimer?.invalidate()
        guard var entry = currentEntry else { return }
        guard force || editorText != lastSavedContent else { return }
        entry.content = editorText
        store.saveEntry(&entry)
        currentEntry = entry
        lastSavedContent = editorText
    }
}
