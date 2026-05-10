import Foundation

enum AppLanguage: String, CaseIterable {
    case system = "System"
    case english = "English"
    case chinese = "中文"

    var resolved: AppLanguage {
        guard self == .system else { return self }
        let lid = Foundation.Locale.current.language.languageCode?.identifier
        return lid == "zh" ? .chinese : .english
    }

    func displayName(_ lang: AppLanguage) -> String {
        switch self {
        case .system: return L.string(.languageSystem, lang: lang)
        case .english: return L.string(.languageEnglish, lang: lang)
        case .chinese: return L.string(.languageChinese, lang: lang)
        }
    }
}

enum L {
    static func en(_ key: LKey) -> String { key.en }
    static func zh(_ key: LKey) -> String { key.zh }

    static func string(_ key: LKey, lang: AppLanguage) -> String {
        lang.resolved == .chinese ? key.zh : key.en
    }
}

// MARK: - String Keys

enum LKey {
    // App
    case newEntry
    case newGroup
    case deleteGroup
    case renameGroup
    case save
    case deleteEntry
    case entryMenu
    case settings
    case preferences

    // Content
    case entries
    case noEntries
    case createFirstEntry
    case create
    case entryName
    case delete
    case deleteEntryTitle
    case deleteEntryMessage
    case cancel
    case rename

    // Settings tabs
    case tabStorage
    case tabEditor
    case tabPreview
    case tabGeneral
    case tabShortcuts

    // Storage section
    case storageLocation
    case entriesDirectory
    case browse
    case fileNaming
    case datePrefix
    case reloadDisk
    case selectFolder

    // Editor section
    case font_
    case fontSize
    case fontSizeValue(Int)
    case layout
    case lineSpacing
    case lineSpacingValue(Int)
    case tabWidth
    case spellCheck

    // Preview section
    case appearance
    case theme
    case systemTheme
    case lightTheme
    case darkTheme
    case softTheme

    // General section
    case language
    case languageSystem
    case languageEnglish
    case languageChinese
    case startup
    case openLastEntry
    case saving
    case autoSaveDelay
    case resetDefaults
    case autoSave05s
    case autoSave1s
    case autoSave2s
    case autoSave5s

    // Shortcuts
    case shortcutSection
    case shortcutNewEntryDesc
    case shortcutSaveDesc
    case shortcutDeleteEntryDesc
    case shortcutSettingsDesc


    // Calendar
    case calendar
    case noEntriesForDate
    case newEntryForDate
    case noEntryToday
    case today
    case sun; case mon; case tue; case wed; case thu; case fri; case sat
    case backToEntries

    // Editor fonts
    case fontSystemMonospaced
    case fontSFMono
    case fontMenlo
    case fontJetBrainsMono

    var en: String {
        switch self {
        case .newEntry: return "New Entry"
        case .newGroup: return "New Group"
        case .deleteGroup: return "Delete Group"
        case .renameGroup: return "Rename Group"
        case .save: return "Save"
        case .deleteEntry: return "Delete Entry"
        case .entryMenu: return "Entry"
        case .settings: return "Settings"
        case .preferences: return "Preferences..."
        case .entries: return "Entries"
        case .noEntries: return "No Entries"
        case .createFirstEntry: return "Create Your First Entry"
        case .create: return "Create"
        case .entryName: return "Name"
        case .delete: return "Delete"
        case .deleteEntryTitle: return "Delete Entry"
        case .deleteEntryMessage: return "Are you sure you want to delete this entry? This action can be undone."
        case .cancel: return "Cancel"
        case .rename: return "Rename"
        case .tabStorage: return "Storage"
        case .tabEditor: return "Editor"
        case .tabPreview: return "Preview"
        case .tabGeneral: return "General"
        case .tabShortcuts: return "Shortcuts"
        case .storageLocation: return "Storage Location"
        case .entriesDirectory: return "Entries directory:"
        case .browse: return "Browse..."
        case .fileNaming: return "File Naming"
        case .datePrefix: return "Prefix filenames with date (YYYY-MM-DD)"
        case .reloadDisk: return "Reload from Disk"
        case .selectFolder: return "Select Diary Storage Folder"
        case .font_: return "Font"
        case .fontSize: return "Font Size"
        case .fontSizeValue(let v): return "Font size: \(v)pt"
        case .layout: return "Layout"
        case .lineSpacing: return "Line Spacing"
        case .lineSpacingValue(let v): return "Line spacing: \(v)pt"
        case .tabWidth: return "Tab Width"
        case .spellCheck: return "Spell Checking"
        case .appearance: return "Appearance"
        case .theme: return "Theme"
        case .systemTheme: return "System"
        case .lightTheme: return "Light"
        case .darkTheme: return "Dark"
        case .softTheme: return "Soft"
        case .language: return "Language"
        case .languageSystem: return "System"
        case .languageEnglish: return "English"
        case .languageChinese: return "中文"
        case .startup: return "Startup"
        case .openLastEntry: return "Open last entry on launch"
        case .saving: return "Saving"
        case .autoSaveDelay: return "Auto-Save Delay"
        case .resetDefaults: return "Reset All Settings to Defaults"
        case .autoSave05s: return "0.5s"
        case .autoSave1s:  return "1s"
        case .autoSave2s:  return "2s"
        case .autoSave5s:  return "5s"
        case .shortcutSection: return "Keyboard Shortcuts"
        case .shortcutNewEntryDesc: return "Create a new diary entry"
        case .shortcutSaveDesc: return "Save current entry"
        case .shortcutDeleteEntryDesc: return "Delete current entry"
        case .shortcutSettingsDesc: return "Open Settings"
        case .calendar: return "Calendar"
        case .noEntriesForDate: return "No entries for this date"
        case .newEntryForDate: return "New entry for this date"
        case .noEntryToday: return "You haven't captured today's beautiful moments yet!"
        case .today: return "Today"
        case .sun: return "Sun"
        case .mon: return "Mon"
        case .tue: return "Tue"
        case .wed: return "Wed"
        case .thu: return "Thu"
        case .fri: return "Fri"
        case .sat: return "Sat"
        case .backToEntries: return "Back to Entries"
        case .fontSystemMonospaced: return "System Monospaced"
        case .fontSFMono:           return "SF Mono"
        case .fontMenlo:            return "Menlo"
        case .fontJetBrainsMono:    return "JetBrains Mono"
        }
    }

    var zh: String {
        switch self {
        case .newEntry: return "新建"
        case .newGroup: return "新建分组"
        case .deleteGroup: return "删除分组"
        case .renameGroup: return "重命名分组"
        case .save: return "保存"
        case .deleteEntry: return "删除日记"
        case .entryMenu: return "日记"
        case .settings: return "设置"
        case .preferences: return "偏好设置..."
        case .entries: return "日记"
        case .noEntries: return "没有日记"
        case .createFirstEntry: return "创建第一篇日记"
        case .create: return "创建"
        case .entryName: return "名称"
        case .delete: return "删除"
        case .deleteEntryTitle: return "删除日记"
        case .deleteEntryMessage: return "确定要删除这篇日记吗？此操作可以撤销。"
        case .cancel: return "取消"
        case .rename: return "重命名"
        case .tabStorage: return "存储"
        case .tabEditor: return "编辑器"
        case .tabPreview: return "预览"
        case .tabGeneral: return "通用"
        case .tabShortcuts: return "快捷键"
        case .storageLocation: return "存储位置"
        case .entriesDirectory: return "条目目录："
        case .browse: return "浏览..."
        case .fileNaming: return "文件命名"
        case .datePrefix: return "文件名加日期前缀（YYYY-MM-DD）"
        case .reloadDisk: return "从磁盘重新加载"
        case .selectFolder: return "选择日记存储文件夹"
        case .font_: return "字体"
        case .fontSize: return "字号"
        case .fontSizeValue(let v): return "字号：\(v)pt"
        case .layout: return "布局"
        case .lineSpacing: return "行间距"
        case .lineSpacingValue(let v): return "行间距：\(v)pt"
        case .tabWidth: return "Tab 宽度"
        case .spellCheck: return "拼写检查"
        case .appearance: return "外观"
        case .theme: return "主题"
        case .systemTheme: return "跟随系统"
        case .lightTheme: return "浅色"
        case .darkTheme: return "深色"
        case .softTheme: return "柔和"
        case .language: return "语言"
        case .languageSystem: return "跟随系统"
        case .languageEnglish: return "English"
        case .languageChinese: return "中文"
        case .startup: return "启动"
        case .openLastEntry: return "启动时打开上次的条目"
        case .saving: return "保存"
        case .autoSaveDelay: return "自动保存延迟"
        case .resetDefaults: return "重置所有设置为默认值"
        case .autoSave05s: return "0.5秒"
        case .autoSave1s:  return "1秒"
        case .autoSave2s:  return "2秒"
        case .autoSave5s:  return "5秒"
        case .shortcutSection: return "键盘快捷键"
        case .shortcutNewEntryDesc: return "新建一篇日记"
        case .shortcutSaveDesc: return "保存当前日记"
        case .shortcutDeleteEntryDesc: return "删除当前日记"
        case .shortcutSettingsDesc: return "打开设置"
        case .calendar: return "日历"
        case .noEntriesForDate: return "该日期没有日记"
        case .newEntryForDate: return "为此日期新建日记"
        case .noEntryToday: return "你今天还没记录下生活的美好哦！"
        case .today: return "今天"
        case .sun: return "日"
        case .mon: return "一"
        case .tue: return "二"
        case .wed: return "三"
        case .thu: return "四"
        case .fri: return "五"
        case .sat: return "六"
        case .backToEntries: return "返回日记列表"
        case .fontSystemMonospaced: return "系统等宽"
        case .fontSFMono:           return "SF Mono"
        case .fontMenlo:            return "Menlo"
        case .fontJetBrainsMono:    return "JetBrains Mono"
        }
    }
}
