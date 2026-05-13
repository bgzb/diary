import SwiftUI

// MARK: - Cyclical wheel column

private struct WheelColumnView: View {
    @Binding var selection: Int
    let values: [Int]          // e.g. [0..<24] or [0,5,...,55]
    let label: String
    let itemHeight: CGFloat

    // 3 repetitions for seamless cycling
    private var displayValues: [Int] { values + values + values }
    private var middleStart: Int { values.count }
    private let viewHeight: CGFloat = 216  // 6 items visible
    private let centerOffset: Int

    @State private var topItem: Int?
    @State private var needsEdgeJump = false

    init(selection: Binding<Int>, values: [Int], label: String, itemHeight: CGFloat = 36) {
        self._selection = selection
        self.values = values
        self.label = label
        self.itemHeight = itemHeight
        // Number of items that fit from top to center
        let halfVisible = Int(216 / itemHeight) / 2
        self.centerOffset = halfVisible
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(displayValues.enumerated()), id: \.offset) { idx, value in
                            WheelItemView(
                                value: value,
                                isSelected: selection == value,
                                itemHeight: itemHeight,
                                onTap: {
                                    selection = value
                                    // Find nearest display index for this value
                                    let targetIdx = nearestIndex(for: value)
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        proxy.scrollTo(targetIdx, anchor: .center)
                                    }
                                }
                            )
                            .id(idx)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $topItem)
                .frame(height: viewHeight)
                .onChange(of: topItem) { _, newTop in
                    guard let top = newTop else { return }
                    let center = top + centerOffset
                    guard center >= 0, center < displayValues.count else { return }
                    let newValue = displayValues[center]
                    if newValue != selection {
                        selection = newValue
                    }
                    // Edge jump: when near first or third repetition, jump to middle
                    if top < values.count / 2 {
                        let jumpTo = top + values.count
                        needsEdgeJump = true
                        proxy.scrollTo(jumpTo, anchor: .top)
                    } else if top >= 2 * values.count {
                        let jumpTo = top - values.count
                        needsEdgeJump = true
                        proxy.scrollTo(jumpTo, anchor: .top)
                    }
                }
                .onAppear {
                    // Start at middle repetition, selection value
                    let startIdx = middleStart + (values.firstIndex(of: selection) ?? 0)
                    proxy.scrollTo(startIdx, anchor: .center)
                }
                .mask(wheelMask)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                        .frame(height: itemHeight)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    /// Index in displayValues closest to current scroll position that shows the given value.
    private func nearestIndex(for target: Int) -> Int {
        guard let top = topItem else { return middleStart + (values.firstIndex(of: target) ?? 0) }
        let center = top + centerOffset
        // Search within ± values.count range
        var best = center
        var bestDist = Int.max
        for offset in (-values.count)...values.count {
            let idx = center + offset
            guard idx >= 0, idx < displayValues.count else { continue }
            if displayValues[idx] == target {
                let dist = abs(offset)
                if dist < bestDist {
                    bestDist = dist
                    best = idx
                }
            }
        }
        return best
    }

    private var wheelMask: some View {
        VStack(spacing: 0) {
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black]),
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 60)
            Rectangle().fill(.black)
            LinearGradient(
                gradient: Gradient(colors: [.black, .clear]),
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 60)
        }
    }
}

// MARK: - Single wheel item

private struct WheelItemView: View {
    let value: Int
    let isSelected: Bool
    let itemHeight: CGFloat
    let onTap: () -> Void

    var body: some View {
        Text(String(format: "%02d", value))
            .font(.system(size: isSelected ? 20 : 16,
                          weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? .primary : .tertiary)
            .frame(height: itemHeight)
            .frame(maxWidth: .infinity)
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.12)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
    }
}

// MARK: - Time picker window content

struct ReminderTimePickerView: View {
    @Binding var hour: Int
    @Binding var minute: Int
    let language: AppLanguage
    let onDismiss: () -> Void

    private var isChinese: Bool { language.resolved == .chinese }

    private let hours = Array(0..<24)
    private let minutes = Array(stride(from: 0, to: 60, by: 5))

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                WheelColumnView(
                    selection: $hour,
                    values: hours,
                    label: isChinese ? "时" : "Hour"
                )
                WheelColumnView(
                    selection: $minute,
                    values: minutes,
                    label: isChinese ? "分" : "Minute"
                )
            }
            .padding(.top, 16)

            Divider()
                .padding(.vertical, 12)

            Button(isChinese ? "确定" : "Done") {
                onDismiss()
            }
            .keyboardShortcut(.return, modifiers: [])
            .padding(.bottom, 12)
        }
        .frame(width: 180, height: 320)
    }
}
