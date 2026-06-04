import SwiftUI

// MARK: - Live Clock

struct ClockView: View {
    let appLanguage: AppLanguage
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isZh: Bool { appLanguage.resolved == .chinese }

    private var dateString: String {
        let fmt = DateFormatter()
        fmt.locale = isZh ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        fmt.dateFormat = isZh ? "yyyy年M月d日" : "MMM d, yyyy"
        return fmt.string(from: now)
    }

    private var weekdayString: String {
        let fmt = DateFormatter()
        fmt.locale = isZh ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        fmt.dateFormat = "EEEE"
        return fmt.string(from: now)
    }

    private var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt.string(from: now)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 6) {
                Text(dateString)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text(weekdayString)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            Text(timeString)
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .onReceive(timer) { t in
            now = t
        }
    }
}
