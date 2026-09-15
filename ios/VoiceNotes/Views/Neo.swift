import SwiftUI

enum Neo {
    static let ink = Color.black
    static let paper = Color(red: 0.97, green: 0.95, blue: 0.90)
    static let card = Color.white
    static let red = Color(red: 1.0, green: 0.42, blue: 0.42)
    static let redSoft = Color(red: 1.0, green: 0.84, blue: 0.84)
    static let green = Color(red: 0.55, green: 0.90, blue: 0.55)
    static let greenSoft = Color(red: 0.84, green: 0.96, blue: 0.84)
    static let yellow = Color(red: 1.0, green: 0.87, blue: 0.40)
    static let muted = Color(red: 0.35, green: 0.35, blue: 0.35)
    static let radius: CGFloat = 6
    static let border: CGFloat = 2
    static let shadow: CGFloat = 4
}

struct NeoCard: ViewModifier {
    var fill: Color
    var shadow: CGFloat
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(fill)
                    .background(
                        RoundedRectangle(cornerRadius: radius)
                            .fill(Neo.ink)
                            .offset(x: shadow, y: shadow)
                    )
                    .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Neo.ink, lineWidth: Neo.border))
            )
    }
}

struct NeoButtonStyle: ButtonStyle {
    var fill: Color = Neo.card
    var shadow: CGFloat = Neo.shadow

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.bold))
            .foregroundStyle(Neo.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Neo.radius)
                    .fill(fill)
                    .overlay(RoundedRectangle(cornerRadius: Neo.radius).strokeBorder(Neo.ink, lineWidth: Neo.border))
            )
            .background(
                RoundedRectangle(cornerRadius: Neo.radius)
                    .fill(Neo.ink)
                    .offset(x: configuration.isPressed ? 0 : shadow, y: configuration.isPressed ? 0 : shadow)
            )
            .offset(x: configuration.isPressed ? shadow : 0, y: configuration.isPressed ? shadow : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

struct NeoIconButtonStyle: ButtonStyle {
    var fill: Color = Neo.card
    var size: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.bold))
            .foregroundStyle(Neo.ink)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: Neo.radius)
                    .fill(fill)
                    .overlay(RoundedRectangle(cornerRadius: Neo.radius).strokeBorder(Neo.ink, lineWidth: Neo.border))
            )
            .background(
                RoundedRectangle(cornerRadius: Neo.radius)
                    .fill(Neo.ink)
                    .offset(x: configuration.isPressed ? 0 : Neo.shadow, y: configuration.isPressed ? 0 : Neo.shadow)
            )
            .offset(x: configuration.isPressed ? Neo.shadow : 0, y: configuration.isPressed ? Neo.shadow : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

extension View {
    func neoCard(_ fill: Color = Neo.card, shadow: CGFloat = Neo.shadow, radius: CGFloat = Neo.radius) -> some View {
        modifier(NeoCard(fill: fill, shadow: shadow, radius: radius))
    }

    func neoField() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Neo.radius)
                    .fill(Neo.card)
                    .overlay(RoundedRectangle(cornerRadius: Neo.radius).strokeBorder(Neo.ink, lineWidth: Neo.border))
            )
    }
}

struct NeoSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.footnote.weight(.black))
            .foregroundStyle(Neo.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Neo.yellow)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Neo.ink, lineWidth: Neo.border))
            )
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        return place(subviews: subviews, in: width).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = place(subviews: subviews, in: bounds.width)
        for (subview, origin) in zip(subviews, result.origins) {
            subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func place(subviews: Subviews, in width: CGFloat) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowHeight), origins)
    }
}

struct NeoTag: View {
    let text: String
    var fill: Color = Neo.greenSoft

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(Neo.ink)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(fill)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Neo.ink, lineWidth: 1.5))
            )
    }
}
