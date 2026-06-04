import SwiftUI

enum CalendarPanelMode {
    case inspector
    case standalone
}

struct CalendarPanelView: View {
    @Environment(ViewModel.self) private var model
    @Environment(SettingsStore.self) private var settings

    let mode: CalendarPanelMode
    @Binding var showCalendarStandalone: Bool
    @State private var displayedMonth = Date()

    var body: some View {
        switch mode {
        case .inspector:
            inspectorView
        case .standalone:
            standaloneView
        }
    }

    // MARK: - Inspector (side panel)

    private var inspectorView: some View {
        VStack(spacing: 0) {
            CalendarView(
                displayedMonth: $displayedMonth,
                entryDates: model.entryDates,
                selectedDate: Binding(
                    get: { model.selectedDate },
                    set: { model.selectedDate = $0 }
                ),
                appLanguage: settings.appLanguage
            )
            .padding(12)

            Divider()

            if let date = model.selectedDate {
                dateEntriesList(date, inInspector: true)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 24, weight: .ultraLight))
                        .foregroundStyle(.tertiary)
                    Text(L.string(.calendar, lang: settings.appLanguage))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("Select a date to filter entries")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(contentBackground)
    }

    // MARK: - Standalone (full content)

    private var standaloneView: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    showCalendarStandalone = false
                } label: {
                    Label(L.string(.backToEntries, lang: settings.appLanguage),
                          systemImage: "arrow.left")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }

            CalendarView(
                displayedMonth: $displayedMonth,
                entryDates: model.entryDates,
                selectedDate: Binding(
                    get: { model.selectedDate },
                    set: { model.selectedDate = $0 }
                ),
                appLanguage: settings.appLanguage
            )
            .padding(.horizontal, 40)
            .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 20)

            if let date = model.selectedDate {
                dateEntriesList(date, inInspector: false)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 28, weight: .ultraLight))
                        .foregroundStyle(.tertiary)
                    Text("Select a date to view entries")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Date Entries List

    private func dateEntriesList(_ date: Date, inInspector: Bool) -> some View {
        let matching = model.entriesForSelectedDate()

        return VStack(spacing: 0) {
            HStack {
                Text(dateDisplayString(date))
                    .font(.system(size: inInspector ? 12 : 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !matching.isEmpty {
                    Text("\(matching.count) entries")
                        .font(.system(size: inInspector ? 11 : 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, inInspector ? 12 : 40)
            .padding(.vertical, inInspector ? 8 : 10)

            if matching.isEmpty {
                VStack(spacing: 0) {
                    Spacer()
                    if Calendar.current.isDateInToday(date) {
                        VStack(spacing: inInspector ? 12 : 16) {
                            Image(systemName: "sun.max")
                                .font(.system(size: inInspector ? 28 : 40, weight: .ultraLight))
                                .foregroundStyle(.tertiary)
                            Text(L.string(.noEntryToday, lang: settings.appLanguage))
                                .font(.system(size: inInspector ? 13 : 15))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button {
                                model.newEntry()
                            } label: {
                                Label(L.string(.newEntry, lang: settings.appLanguage),
                                      systemImage: "square.and.pencil")
                                    .font(.system(size: 12))
                            }
                        }
                        .padding(.horizontal, inInspector ? 16 : 0)
                    } else {
                        Text(L.string(.noEntriesForDate, lang: settings.appLanguage))
                            .font(.system(size: inInspector ? 12 : 13))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(Array(matching.enumerated()), id: \.offset) { _, pair in
                    let (entry, groupName) = pair
                    Button {
                        // Switch to the entry's group, then select the entry
                        if let group = model.groups.first(where: { $0.name == groupName }) {
                            model.selectGroup(group)
                        }
                        // Re-fetch the entry from the new current group
                        if let reloaded = model.entries.first(where: { $0.id == entry.id }) {
                            model.selectEntry(reloaded)
                        }
                        if !inInspector {
                            showCalendarStandalone = false
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: inInspector ? 2 : 3) {
                            HStack {
                                Text(entry.title)
                                    .font(.system(size: inInspector ? 12 : 14))
                                    .lineLimit(1)
                                Spacer()
                                Text(groupName)
                                    .font(.system(size: inInspector ? 9 : 10))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, inInspector ? 4 : 5)
                                    .padding(.vertical, 1)
                                    .background(Color.primary.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: inInspector ? 2 : 3))
                            }
                            Text(modifiedAtString(entry.modifiedAt))
                                .font(.system(size: inInspector ? 10 : 11))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, inInspector ? 2 : 4)
                        .padding(.horizontal, inInspector ? 8 : 24)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        entry.id == model.currentEntry?.id
                            ? Color.accentColor.opacity(0.1)
                            : Color.clear
                    )
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Helpers

    private func dateDisplayString(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMMM d, yyyy"
        return df.string(from: date)
    }

    private func modifiedAtString(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df.string(from: date)
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
}
