import Foundation

struct Entry: Identifiable, Hashable {
    let id: String
    var title: String
    var content: String
    var fileURL: URL
    let createdAt: Date
    var modifiedAt: Date

    init(id: String = UUID().uuidString, title: String, content: String = "", fileURL: URL) {
        self.id = id
        self.title = title
        self.content = content
        self.fileURL = fileURL
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}

struct DiaryGroup: Identifiable, Codable {
    var id: String
    var name: String
    var order: Int
}

@Observable
final class EntryStore {
    var entries: [Entry] = []
    var groups: [DiaryGroup] = []
    var currentGroupID: String = "" {
        didSet { if oldValue != currentGroupID { switchGroup() } }
    }
    private var baseDir: URL
    var useDatePrefix: Bool
    private var currentGroupDir: URL { baseDir.appendingPathComponent(currentGroupID) }

    init(basePath: String, useDatePrefix: Bool) {
        self.baseDir = URL(fileURLWithPath: (basePath as NSString).expandingTildeInPath)
        self.useDatePrefix = useDatePrefix
        ensureDirectory()
        migrateLegacyEntries()
        loadGroups()
        if groups.isEmpty {
            createGroup(name: "Diary")
        }
        currentGroupID = groups.first!.id
        loadEntries()
        if entries.isEmpty {
            createWelcomeEntry()
        }
    }

    /// Switch to a new storage root
    func reload(basePath: String) {
        flushAll()
        baseDir = URL(fileURLWithPath: (basePath as NSString).expandingTildeInPath)
        entries = []
        groups = []
        ensureDirectory()
        migrateLegacyEntries()
        loadGroups()
        if groups.isEmpty {
            createGroup(name: "Diary")
        }
        currentGroupID = groups.first!.id
        loadEntries()
        if entries.isEmpty {
            createWelcomeEntry()
        }
    }

    // MARK: - Groups

    @discardableResult
    func createGroup(name: String) -> DiaryGroup {
        let group = DiaryGroup(
            id: UUID().uuidString,
            name: name,
            order: groups.count
        )
        groups.append(group)
        let dir = baseDir.appendingPathComponent(group.id)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Create welcome entry for the new group
        let welcomeURL = dir.appendingPathComponent("Welcome.md")
        try? welcomeContent(for: name).write(to: welcomeURL, atomically: true, encoding: .utf8)
        persistGroups()
        return group
    }

    func selectGroup(_ group: DiaryGroup) {
        guard group.id != currentGroupID else { return }
        flushAll()
        currentGroupID = group.id
    }

    func renameGroup(_ group: DiaryGroup, to newName: String) {
        guard let idx = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[idx].name = newName
        persistGroups()
    }

    func deleteGroup(_ group: DiaryGroup) {
        guard groups.count > 1 else { return }
        // Remove group directory from disk
        let dir = baseDir.appendingPathComponent(group.id)
        try? FileManager.default.removeItem(at: dir)
        groups.removeAll { $0.id == group.id }
        persistGroups()
        // If deleting current group, switch to first available
        if currentGroupID == group.id {
            currentGroupID = groups.first!.id
            loadEntries()
        }
    }

    func restoreGroup(_ group: DiaryGroup) {
        groups.append(group)
        groups.sort { $0.order < $1.order }
        let dir = baseDir.appendingPathComponent(group.id)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        persistGroups()
    }

    func reorderGroups(fromOffsets source: IndexSet, toOffset destination: Int) {
        groups.move(fromOffsets: source, toOffset: destination)
        for (i, _) in groups.enumerated() {
            groups[i].order = i
        }
        persistGroups()
    }

    // MARK: - Entries

    @discardableResult
    func createEntry(title: String) -> Entry {
        let sanitized = title.replacingOccurrences(of: "/", with: "-")
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let today = df.string(from: Date())
        let filename: String
        if useDatePrefix && !sanitized.hasPrefix(today) {
            filename = "\(today)-\(sanitized).md"
        } else {
            filename = "\(sanitized).md"
        }

        var url = currentGroupDir.appendingPathComponent(filename)
        var counter = 1
        while FileManager.default.fileExists(atPath: url.path) {
            let stem = (filename as NSString).deletingPathExtension
            url = currentGroupDir.appendingPathComponent("\(stem)-\(counter).md")
            counter += 1
        }

        var entry = Entry(title: sanitized, fileURL: url)
        saveEntry(&entry)
        entries.append(entry)
        entries.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        return entry
    }

    func saveEntry(_ entry: inout Entry) {
        entry.modifiedAt = Date()
        try? entry.content.write(to: entry.fileURL, atomically: true, encoding: .utf8)
    }

    func deleteEntry(_ entry: Entry) {
        try? FileManager.default.removeItem(at: entry.fileURL)
        entries.removeAll { $0.id == entry.id }
    }

    func restoreEntry(_ entry: Entry) {
        try? entry.content.write(to: entry.fileURL, atomically: true, encoding: .utf8)
        entries.append(entry)
        entries.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    @discardableResult
    func renameEntry(_ entry: Entry, to newTitle: String) -> Entry? {
        let sanitized = newTitle.replacingOccurrences(of: "/", with: "-")
        guard sanitized != entry.title else { return entry }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let today = df.string(from: Date())
        let filename: String
        if useDatePrefix && !sanitized.hasPrefix(today) {
            filename = "\(today)-\(sanitized).md"
        } else {
            filename = "\(sanitized).md"
        }

        var url = currentGroupDir.appendingPathComponent(filename)
        var counter = 1
        while url.path != entry.fileURL.path,
              FileManager.default.fileExists(atPath: url.path) {
            let stem = (filename as NSString).deletingPathExtension
            url = currentGroupDir.appendingPathComponent("\(stem)-\(counter).md")
            counter += 1
        }

        try? entry.content.write(to: url, atomically: true, encoding: .utf8)
        if url.path != entry.fileURL.path {
            try? FileManager.default.removeItem(at: entry.fileURL)
        }

        var updated = entry
        updated.title = sanitized
        updated.fileURL = url
        updated.modifiedAt = Date()

        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = updated
        }
        entries.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        return updated
    }

    // MARK: - Private

    private func ensureDirectory() {
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
    }

    private func switchGroup() {
        entries = []
        loadEntries()
        if entries.isEmpty {
            createWelcomeEntry()
        }
    }

    private func loadEntries() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: currentGroupDir,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }

        entries = files
            .filter { $0.pathExtension == "md" }
            .compactMap { url in
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                let filename = url.deletingPathExtension().lastPathComponent
                let displayTitle = displayTitle(from: filename)
                return Entry(
                    id: url.path,
                    title: displayTitle,
                    content: content,
                    fileURL: url
                )
            }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private func displayTitle(from filename: String) -> String {
        if useDatePrefix {
            let pattern = try? NSRegularExpression(pattern: "^\\d{4}-\\d{2}-\\d{2}-")
            let range = NSRange(filename.startIndex..., in: filename)
            if let match = pattern?.firstMatch(in: filename, range: range) {
                return String(filename[Range(match.range, in: filename)!.upperBound...])
            }
        }
        return filename
    }

    private func flushAll() {
        for var entry in entries {
            saveEntry(&entry)
        }
    }

    private func createWelcomeEntry() {
        let groupName = groups.first(where: { $0.id == currentGroupID })?.name ?? "Diary"
        var welcome = Entry(
            title: "Welcome",
            content: welcomeContent(for: groupName),
            fileURL: currentGroupDir.appendingPathComponent("Welcome.md")
        )
        saveEntry(&welcome)
        entries.append(welcome)
    }

    private func welcomeContent(for groupName: String) -> String {
        """
        # \(groupName)

        A clean, distraction-free diary for your daily thoughts.

        Write in **Markdown** — headings, lists, code blocks, and more.

        All entries are saved locally on your disk as plain `.md` files.

        Press **⌘N** or right-click the sidebar to create a new entry.

        Enjoy!
        """
    }

    // MARK: - Group Persistence

    private var groupsFileURL: URL {
        baseDir.appendingPathComponent("_groups.json")
    }

    private func loadGroups() {
        guard let data = try? Data(contentsOf: groupsFileURL),
              let decoded = try? JSONDecoder().decode([DiaryGroup].self, from: data) else { return }
        groups = decoded.sorted { $0.order < $1.order }
    }

    private func persistGroups() {
        guard let data = try? JSONEncoder().encode(groups) else { return }
        try? data.write(to: groupsFileURL)
    }

    // MARK: - Migration

    /// Move old root-level .md files into a default group directory on first launch.
    private func migrateLegacyEntries() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: baseDir,
            includingPropertiesForKeys: nil
        ) else { return }

        let mdFiles = files.filter {
            $0.pathExtension == "md" && $0.lastPathComponent != "_groups.json"
        }
        guard !mdFiles.isEmpty else { return }

        // Check if _groups.json already exists (already migrated)
        if FileManager.default.fileExists(atPath: groupsFileURL.path) { return }

        // Create default group
        let defaultGroup = DiaryGroup(id: UUID().uuidString, name: "Diary", order: 0)
        groups = [defaultGroup]
        let dir = baseDir.appendingPathComponent(defaultGroup.id)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Move .md files into group directory
        for file in mdFiles {
            let dest = dir.appendingPathComponent(file.lastPathComponent)
            try? FileManager.default.moveItem(at: file, to: dest)
        }
        persistGroups()
    }
}
