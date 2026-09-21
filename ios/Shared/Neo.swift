import SwiftUI

enum Neo {
    static let ink = Color(red: 0.18, green: 0.13, blue: 0.11)
    static let paper = Color(red: 0.97, green: 0.95, blue: 0.90)
    static let card = Color.white
    static let red = Color(red: 1.0, green: 0.42, blue: 0.42)
    static let redSoft = Color(red: 1.0, green: 0.84, blue: 0.84)
    static let green = Color(red: 0.55, green: 0.90, blue: 0.55)
    static let greenSoft = Color(red: 0.84, green: 0.96, blue: 0.84)
    static let yellow = Color(red: 1.0, green: 0.87, blue: 0.40)
    static let muted = Color(red: 0.45, green: 0.40, blue: 0.37)
    static let radius: CGFloat = 20
    static let buttonRadius: CGFloat = 16
    static let chipRadius: CGFloat = 8
    static let border: CGFloat = 1.75
    static let chipBorder: CGFloat = 1.25
    static let shadow: CGFloat = 2
    static let buttonShadow: CGFloat = 2.5
}

struct NeoSurface: View {
    var fill: Color = Neo.card
    var radius: CGFloat = Neo.radius
    var border: CGFloat = Neo.border
    var shadow: CGFloat = 0

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    var body: some View {
        shape
            .fill(fill)
            .overlay(shape.fill(LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center)))
            .overlay(shape.strokeBorder(Neo.ink, lineWidth: border))
            .background(shape.fill(Neo.ink).offset(x: shadow, y: shadow))
    }
}

struct NeoPressStyle: ViewModifier {
    let isPressed: Bool
    let fill: Color
    let radius: CGFloat
    let shadow: CGFloat

    func body(content: Content) -> some View {
        content
            .foregroundStyle(Neo.ink)
            .background(NeoSurface(fill: fill, radius: radius, shadow: isPressed ? 0 : shadow))
            .offset(x: isPressed ? shadow : 0, y: isPressed ? shadow : 0)
            .animation(.easeOut(duration: 0.08), value: isPressed)
    }
}

struct NeoButtonStyle: ButtonStyle {
    var fill: Color = Neo.card
    var shadow: CGFloat = Neo.buttonShadow

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.bold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .modifier(NeoPressStyle(isPressed: configuration.isPressed, fill: fill, radius: Neo.buttonRadius, shadow: shadow))
    }
}

struct NeoIconButtonStyle: ButtonStyle {
    var fill: Color = Neo.card
    var size: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.bold))
            .frame(width: size, height: size)
            .modifier(NeoPressStyle(isPressed: configuration.isPressed, fill: fill, radius: Neo.buttonRadius * size / 48, shadow: Neo.buttonShadow))
    }
}

extension View {
    func neoCard(_ fill: Color = Neo.card, shadow: CGFloat = Neo.shadow, radius: CGFloat = Neo.radius) -> some View {
        background(NeoSurface(fill: fill, radius: radius, shadow: shadow))
    }

    func neoChip(_ fill: Color = Neo.card, border: CGFloat = Neo.chipBorder) -> some View {
        background(NeoSurface(fill: fill, radius: Neo.chipRadius, border: border))
    }

    func neoField() -> some View {
        self
            .foregroundStyle(Neo.ink)
            .tint(Neo.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(NeoSurface(radius: Neo.buttonRadius))
            .environment(\.colorScheme, .light)
    }
}

struct NeoSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.footnote.weight(.black))
            .foregroundStyle(Neo.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .neoChip(Neo.yellow)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let size = place(subviews: subviews, in: width).size
        return CGSize(width: width.isFinite ? width : size.width, height: size.height)
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
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .neoChip(fill)
    }
}
