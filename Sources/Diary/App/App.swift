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
    @State private var viewModel: ViewModel?

    var body: some Scene {
        WindowGroup {
            if let vm = viewModel {
                ContentView()
                    .environment(vm)
                    .environment(settings)
                    .frame(minWidth: 700, minHeight: 500)
            } else {
                ProgressView()
                    .task {
                        viewModel = ViewModel(settings: settings)
                    }
            }
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
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Button(format.displayName(settings.appLanguage)) {
                        viewModel?.export(as: format)
                    }
                }
            }
        }

        Settings {
            if let vm = viewModel {
                SettingsView(viewModel: vm, settings: settings)
                    .environment(settings)
            }
        }
    }
}
