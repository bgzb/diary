import SwiftUI

struct ReminderTimePickerView: View {
    @Binding var hour: Int
    @Binding var minute: Int
    let language: AppLanguage
    let onDismiss: () -> Void

    private var isChinese: Bool { language.resolved == .chinese }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                wheelColumn(
                    selection: $hour,
                    values: Array(0..<24),
                    label: isChinese ? "时" : "Hour"
                )
                wheelColumn(
                    selection: $minute,
                    values: Array(stride(from: 0, to: 60, by: 5)),
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

    private func wheelColumn(selection: Binding<Int>, values: [Int], label: String) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(values, id: \.self) { value in
                            let selected = selection.wrappedValue == value
                            Text(String(format: "%02d", value))
                                .font(.system(size: selected ? 20 : 16, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? .primary : .tertiary)
                                .frame(height: 36)
                                .frame(maxWidth: .infinity)
                                .background(
                                    selected
                                        ? Color.accentColor.opacity(0.12)
                                        : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selection.wrappedValue = value
                                    }
                                }
                                .id(value)
                        }
                    }
                    .padding(.vertical, 108)
                }
                .frame(width: 72, height: 216)
                .mask(
                    VStack(spacing: 0) {
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 60)
                        Rectangle().fill(.black)
                        LinearGradient(
                            gradient: Gradient(colors: [.black, .clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 60)
                    }
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                        .frame(height: 36)
                        .allowsHitTesting(false)
                }
                .onChange(of: selection.wrappedValue) { _, new in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(new, anchor: .center)
                    }
                }
                .onAppear {
                    proxy.scrollTo(selection.wrappedValue, anchor: .center)
                }
            }
        }
    }
}
