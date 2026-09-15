import SwiftUI

struct MoodGlyph: View {
    @Environment(MoodIconStore.self) private var icons

    let mood: Int
    var size: CGFloat = 26

    var body: some View {
        if let image = icons.image(for: mood) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .frame(width: size, height: size)
                .foregroundStyle(Neo.ink)
        } else {
            Circle()
                .strokeBorder(Neo.ink.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .frame(width: size, height: size)
        }
    }
}

struct MoodPickerRow: View {
    let selected: Int
    var size: CGFloat = 34
    let onPick: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...MoodIcons.count, id: \.self) { mood in
                Button {
                    onPick(mood == selected ? 0 : mood)
                } label: {
                    MoodGlyph(mood: mood, size: size)
                        .padding(6)
                }
                .buttonStyle(NeoIconButtonStyle(fill: mood == selected ? Neo.green : Neo.card, size: size + 14))
                .accessibilityLabel("Mood \(mood)")
            }
        }
    }
}
