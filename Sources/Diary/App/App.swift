import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        ReminderManager.requestPermission()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct DiaryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var settings = SettingsStore()
    @State private var lockManager = LockManager()
    @State private var viewModel: ViewModel?

    private var colorScheme: ColorScheme? {
        switch settings.previewTheme {
        case .system: return nil
        case .light, .grey: return .light
        case .dark: return .dark
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let vm = viewModel {
                    if lockManager.isLocked {
                        LockScreenView()
                            .environment(settings)
                            .environment(lockManager)
                            .frame(minWidth: 700, minHeight: 500)
                    } else {
                        ContentView()
                            .environment(vm)
                            .environment(settings)
                            .environment(lockManager)
                            .frame(minWidth: 700, minHeight: 500)
                    }
                } else {
                    ProgressView()
                        .task {
                            viewModel = ViewModel(settings: settings)
                        }
                }
            }
            .preferredColorScheme(colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 900, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(L.string(.newEntry, lang: settings.appLanguage)) {
                    viewModel?.newEntry()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(replacing: .saveItem) {
                Button(L.string(.save, lang: settings.appLanguage)) {
                    viewModel?.saveCurrentEntry()
                }
                .keyboardShortcut("s", modifiers: .command)
            }
            CommandMenu(L.string(.entryMenu, lang: settings.appLanguage)) {
                Button(L.string(.deleteEntry, lang: settings.appLanguage)) {
                    viewModel?.pendingDelete = true
                }
                .keyboardShortcut("d", modifiers: .command)
            }
            CommandMenu(L.string(.exportMenu, lang: settings.appLanguage)) {
                Button(L.string(.exportTitle, lang: settings.appLanguage)) {
                    viewModel?.export()
                }
                .keyboardShortcut("p", modifiers: .command)
            }
        }

        Settings {
            if let vm = viewModel {
                SettingsView(viewModel: vm, settings: settings)
                    .environment(settings)
                    .environment(lockManager)
            }
        }
    }
}
