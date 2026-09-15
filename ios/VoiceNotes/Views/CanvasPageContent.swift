import SwiftUI

struct CanvasPageContent<Content: View>: View {
    let paper: CanvasPaper
    let pattern: CanvasPattern
    let items: [CanvasItem]
    @ViewBuilder let content: (CanvasItem) -> Content

    var body: some View {
        ZStack {
            paper.color
            CanvasPatternView(pattern: pattern)
            ForEach(items) { item in
                content(item)
            }
        }
        .frame(width: CanvasPage.size.width, height: CanvasPage.size.height)
        .clipped()
    }
}

struct CanvasPatternView: View {
    let pattern: CanvasPattern
    var step: CGFloat = 24

    var body: some View {
        Canvas { context, size in
            var path = Path()
            switch pattern {
            case .plain:
                return
            case .lines:
                for y in stride(from: step, to: size.height, by: step) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(Neo.ink.opacity(0.14)), lineWidth: 1)
            case .dots:
                for y in stride(from: step, to: size.height, by: step) {
                    for x in stride(from: step, to: size.width, by: step) {
                        path.addEllipse(in: CGRect(x: x - 1.25, y: y - 1.25, width: 2.5, height: 2.5))
                    }
                }
                context.fill(path, with: .color(Neo.ink.opacity(0.22)))
            }
        }
    }
}

struct ScrapView: View {
    let image: UIImage?
    let isCutout: Bool

    var body: some View {
        if isCutout {
            picture
        } else {
            picture
                .padding(CanvasPage.padding)
                .neoCard(Neo.card, shadow: 3, radius: 2)
        }
    }

    @ViewBuilder
    private var picture: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
        } else {
            Color.clear
        }
    }
}

struct CanvasItemView: View {
    let item: CanvasItem
    let image: UIImage?
    var busy = false
    let onBegin: () -> Void
    let onCommit: () -> Void
    let onToggleCutout: () -> Void
    let onDelete: () -> Void

    @GestureState private var drag: CGSize = .zero
    @GestureState private var magnification: CGFloat = 1
    @GestureState private var twist: Angle = .zero
    @State private var began = false

    var body: some View {
        let size = item.frameSize(width: CanvasPage.clampWidth(item.width * magnification))
        ScrapView(image: image, isCutout: item.isCutout)
            .frame(width: size.width, height: size.height)
            .overlay {
                if busy {
                    ProgressView()
                        .padding(8)
                        .background(Neo.card, in: RoundedRectangle(cornerRadius: Neo.radius))
                }
            }
            .contextMenu {
                if item.isCutout {
                    Button("Restore background", systemImage: "photo", action: onToggleCutout)
                } else {
                    Button("Remove background", systemImage: "scissors", action: onToggleCutout)
                }
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            }
            .gesture(gestures)
            .rotationEffect(.radians(item.rotation) + twist)
            .position(x: item.x + drag.width, y: item.y + drag.height)
            .zIndex(Double(item.z))
    }

    private var gestures: some Gesture {
        let move = DragGesture(minimumDistance: 2, coordinateSpace: .named(CanvasPage.space))
            .updating($drag) { value, state, _ in
                state = value.translation
            }
            .onChanged { _ in
                if !began {
                    began = true
                    onBegin()
                }
            }
            .onEnded { value in
                item.x = min(max(item.x + value.translation.width, 0), CanvasPage.size.width)
                item.y = min(max(item.y + value.translation.height, 0), CanvasPage.size.height)
                began = false
                onCommit()
            }
        let resize = MagnifyGesture()
            .updating($magnification) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                item.width = CanvasPage.clampWidth(item.width * value.magnification)
                onCommit()
            }
        let rotate = RotateGesture()
            .updating($twist) { value, state, _ in
                state = value.rotation
            }
            .onEnded { value in
                item.rotation += value.rotation.radians
                onCommit()
            }
        return move.simultaneously(with: resize).simultaneously(with: rotate)
    }
}
