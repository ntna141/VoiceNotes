import SwiftUI

struct DayPickerCard: View {
    let onAdd: (String) -> Void
    let onCancel: () -> Void

    @State private var dayKey = DayKey.today

    var body: some View {
        ZStack {
            Neo.paper
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Add to page")
                    .font(.title2.weight(.black))
                    .foregroundStyle(Neo.ink)
                HStack(spacing: 12) {
                    dayButton(offset: -1)
                    Text(DayKey.shortLabel(dayKey))
                        .font(.headline.weight(.black))
                        .foregroundStyle(Neo.ink)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                    dayButton(offset: 1)
                }
                HStack(spacing: 12) {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(NeoButtonStyle())
                    Button {
                        onAdd(dayKey)
                    } label: {
                        Text("Add")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(NeoButtonStyle(fill: Neo.green))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .neoCard()
            .padding(.horizontal, 20)
            .padding(.trailing, Neo.shadow)
        }
        .tint(Neo.ink)
    }

    private func dayButton(offset: Int) -> some View {
        let target = DayKey.shifted(dayKey, by: offset) ?? dayKey
        let allowed = target <= DayKey.today
        return Button {
            dayKey = target
        } label: {
            Image(systemName: offset < 0 ? "chevron.left" : "chevron.right")
        }
        .buttonStyle(NeoIconButtonStyle(size: 40))
        .disabled(!allowed)
        .opacity(allowed ? 1 : 0.4)
        .accessibilityLabel(offset < 0 ? "Previous day" : "Next day")
    }
}
