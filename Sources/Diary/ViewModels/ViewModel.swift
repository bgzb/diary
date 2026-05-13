import SwiftUI
import Observation

enum SearchMode: CaseIterable, Hashable {
    case title
    case content

    func displayName(_ lang: AppLanguage) -> String {
        switch self {
        case .title: return L.string(.searchByTitle, lang: lang)
        case .content: return L.string(.searchByContent, lang: lang)
        }
    }
}

struct SearchResultEntry: Identifiable {
    var id: String { entry.id }
    let entry: Entry
    var matchCount: Int
}

struct SearchResultGroup: Identifiable {
    var id: String { groupID }
    let groupID: String
    let groupName: String
    var entries: [SearchResultEntry]
}

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

    var searchText = "" {
        didSet { scheduleSearch() }
    }
    var searchMode: SearchMode = .title {
        didSet { if isSearchActive { scheduleSearch() } }
    }
    var searchResults: [SearchResultGroup] = []
    var isSearchActive: Bool { !searchText.isEmpty }
    var totalSearchResultCount: Int {
        searchResults.reduce(0) { $0 + $1.entries.count }
    }

    var selectedDate: Date?

    var wordCount: Int {
        editorText.split { $0.isWhitespace || $0.isNewline }.count
    }

    var charCount: Int {
        editorText.count
    }

    var writingStreak: Int {
        let dates = entryDates
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let start: Date
        if dates.contains(today) {
            start = today
        } else {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
            start = yesterday
        }

        var count = 0
        var day = start
        while dates.contains(day) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    private var cachedEntryDates: Set<Date>?

    var entryDates: Set<Date> {
        if let cached = cachedEntryDates { return cached }
        let dates = Set(store.allEntryDates().map { Calendar.current.startOfDay(for: $0) })
        cachedEntryDates = dates
        return dates
    }

    private func invalidateEntryDatesCache() {
        cachedEntryDates = nil
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

    func isPinned(_ entry: Entry) -> Bool {
        store.isPinned(entry)
    }

    func togglePin(_ entry: Entry) {
        store.togglePin(entry)
        if entry.id == currentEntry?.id {
            currentEntry = store.entries.first(where: { $0.id == entry.id })
        }
    }

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
        invalidateEntryDatesCache()
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
        invalidateEntryDatesCache()
        currentEntry = store.entries.first
    }

    func reloadStorage() {
        flushSave()
        store.reload(basePath: settings.resolvedStoragePath)
        invalidateEntryDatesCache()
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
        invalidateEntryDatesCache()
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
        invalidateEntryDatesCache()
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

    // MARK: - Export

    func export(as format: ExportFormat) {
        guard let entry = currentEntry else { return }
        ExportManager.export(entry: entry, format: format, settings: settings)
    }

    // MARK: - Search

    private var searchTimer: Timer?

    private func scheduleSearch() {
        searchTimer?.invalidate()
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
            self?.performSearch()
        }
    }

    private func performSearch() {
        let query = searchText.lowercased()
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        var grouped: [SearchResultGroup] = []
        let baseDir = URL(fileURLWithPath: (settings.resolvedStoragePath as NSString).expandingTildeInPath)

        for group in store.groups {
            let dir = baseDir.appendingPathComponent(group.id)
            guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            var groupEntries: [SearchResultEntry] = []

            for file in files where file.pathExtension == "md" {
                guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
                let filename = file.deletingPathExtension().lastPathComponent
                let title = displayTitleForSearch(from: filename, in: file)
                let lowerTitle = title.lowercased()
                let lowerContent = content.lowercased()

                let matches: Bool
                let matchCount: Int

                switch searchMode {
                case .title:
                    matches = lowerTitle.contains(query)
                    matchCount = matches ? 1 : 0
                case .content:
                    matchCount = countMatches(of: query, in: lowerContent)
                    matches = matchCount > 0
                }

                guard matches else { continue }

                let attrs = try? FileManager.default.attributesOfItem(atPath: file.path)
                var entry = Entry(id: file.path, title: title, content: content, fileURL: file)
                if let mod = attrs?[.modificationDate] as? Date { entry.modifiedAt = mod }
                if let cr = attrs?[.creationDate] as? Date { entry.createdAt = cr }
                groupEntries.append(SearchResultEntry(entry: entry, matchCount: matchCount))
            }

            if !groupEntries.isEmpty {
                grouped.append(SearchResultGroup(
                    groupID: group.id,
                    groupName: group.name,
                    entries: groupEntries
                ))
            }
        }

        searchResults = grouped
    }

    private func countMatches(of query: String, in text: String) -> Int {
        guard !query.isEmpty else { return 0 }
        var count = 0
        var searchStart = text.startIndex
        while let range = text[searchStart...].range(of: query) {
            count += 1
            searchStart = range.upperBound
            guard searchStart < text.endIndex else { break }
        }
        return count
    }

    private func displayTitleForSearch(from filename: String, in fileURL: URL) -> String {
        if settings.useDatePrefix {
            let pattern = try? NSRegularExpression(pattern: "^\\d{4}-\\d{2}-\\d{2}-")
            let range = NSRange(filename.startIndex..., in: filename)
            if let match = pattern?.firstMatch(in: filename, range: range) {
                return String(filename[Range(match.range, in: filename)!.upperBound...])
            }
        }
        return filename
    }

    func selectSearchResult(_ entry: Entry) {
        let baseDir = URL(fileURLWithPath: (settings.resolvedStoragePath as NSString).expandingTildeInPath)
        for group in store.groups {
            let dir = baseDir.appendingPathComponent(group.id)
            if entry.fileURL.path.hasPrefix(dir.path) {
                if group.id != store.currentGroupID {
                    selectGroup(group)
                }
                break
            }
        }
        if let match = store.entries.first(where: { $0.id == entry.id }) {
            selectEntry(match)
        }
        searchText = ""
    }
}
