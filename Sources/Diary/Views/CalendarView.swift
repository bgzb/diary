import SwiftUI

struct CalendarView: View {
    @Binding var displayedMonth: Date
    let entryDates: Set<Date>
    @Binding var selectedDate: Date?
    let appLanguage: AppLanguage

    private let calendar = Calendar.current
    private let cols = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            monthHeader
            weekdayHeader
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(0..<gridDates.count, id: \.self) { i in
                    if let date = gridDates[i] {
                        dayCell(date)
                    } else {
                        Color.clear
                    }
                }
            }
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth)!
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Text(monthYearString)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 120)

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth)!
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button {
                displayedMonth = Date()
                selectedDate = Date()
            } label: {
                Text(L.string(.today, lang: appLanguage))
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private var monthYearString: String {
        let df = DateFormatter()
        df.dateFormat = "MMMM yyyy"
        return df.string(from: displayedMonth)
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        LazyVGrid(columns: cols, spacing: 4) {
            ForEach(weekdaySymbols, id: \.self) { sym in
                Text(sym)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var weekdaySymbols: [String] {
        let syms: [LKey] = [.sun, .mon, .tue, .wed, .thu, .fri, .sat]
        let first = calendar.firstWeekday - 1
        return (0..<7).map { L.string(syms[(first + $0) % 7], lang: appLanguage) }
    }

    // MARK: - Day Cell

    private func dayCell(_ date: Date) -> some View {
        let inMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
        let isToday = calendar.isDateInToday(date)
        let isSel = selectedDate != nil && calendar.isDate(date, inSameDayAs: selectedDate!)
        let hasEntry = entryDates.contains(calendar.startOfDay(for: date))

        return Button {
            if isSel {
                selectedDate = nil
            } else {
                selectedDate = date
                if !inMonth {
                    var comps = calendar.dateComponents([.year, .month], from: date)
                    comps.day = 1
                    if let firstOfMonth = calendar.date(from: comps) {
                        displayedMonth = firstOfMonth
                    }
                }
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 12, weight: isToday ? .bold : .regular))
                    .frame(width: 24, height: 24)
                    .background(
                        isToday ? Circle().fill(Color.accentColor) :
                        isSel   ? Circle().fill(Color.accentColor.opacity(0.25)) :
                        nil
                    )
                    .foregroundStyle(isToday ? Color.white : Color.primary)
                    .opacity(inMonth ? 1.0 : 0.35)
                if hasEntry {
                    Circle()
                        .fill(isToday ? .white : Color.accentColor)
                        .frame(width: 4, height: 4)
                } else {
                    Spacer().frame(height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Grid Dates

    private var gridDates: [Date?] {
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))!
        let weekday = calendar.component(.weekday, from: firstDay)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstDay)!.count

        var dates: [Date?] = []

        if offset > 0 {
            let prevMonth = calendar.date(byAdding: .month, value: -1, to: firstDay)!
            let prevDays = calendar.range(of: .day, in: .month, for: prevMonth)!.count
            for i in (prevDays - offset + 1)...prevDays {
                dates.append(date(prevMonth, day: i))
            }
        }

        for day in 1...daysInMonth {
            dates.append(date(firstDay, day: day))
        }

        let total = dates.count
        let rows = Int(ceil(Double(total) / 7.0))
        let remaining = rows * 7 - total
        if remaining > 0 {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstDay)!
            for day in 1...remaining {
                dates.append(date(nextMonth, day: day))
            }
        }

        return dates
    }

    private func date(_ month: Date, day: Int) -> Date? {
        var comps = calendar.dateComponents([.year, .month], from: month)
        comps.day = day
        return calendar.date(from: comps)
    }
}
