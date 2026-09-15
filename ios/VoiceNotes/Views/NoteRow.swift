import SwiftUI

struct NoteRow: View {
    let note: Note
    let mood: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(note.displayTitle)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Neo.ink)
                    .lineLimit(1)
                Text(note.preview)
                    .font(.subheadline)
                    .foregroundStyle(Neo.muted)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    NeoTag(text: NoteSections.rowDate(note.createdAt), fill: Neo.card)
                    if note.hasAudio {
                        NeoTag(text: "AUDIO", fill: statusFill)
                    }
                    if note.transcription.isPending {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(Neo.ink)
                    }
                }
            }
            Spacer(minLength: 0)
            if mood != 0 {
                MoodGlyph(mood: mood, size: 28)
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Neo.greenSoft)
                            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Neo.ink, lineWidth: 1.5))
                    )
            }
        }
        .padding(12)
        .neoCard(rowFill)
    }

    private var rowFill: Color {
        switch note.transcription {
        case .failed: return Neo.redSoft
        case .recording: return Neo.yellow
        default: return Neo.card
        }
    }

    private var statusFill: Color {
        switch note.transcription {
        case .done: return Neo.green
        case .failed: return Neo.red
        default: return Neo.yellow
        }
    }
}
