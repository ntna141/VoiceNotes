import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum Drop {
    case none
    case hard(CGFloat, Color)
    case soft(radius: CGFloat, y: CGFloat, opacity: Double)
    case lip(CGFloat)
}

enum Grid {
    case none, dots, ruled
}

struct PaperFX {
    var grain = false
    var grid = Grid.none
    var tape = false
    var tilt = false
    var sketchy = false
    var highlighter = false
    var stamp = false
    var handFont: String? = nil
}

struct Style {
    var name: String
    var blurb: String
    var paper: Color
    var card: Color
    var ink: Color
    var muted: Color
    var red: Color
    var redSoft: Color
    var green: Color
    var greenSoft: Color
    var yellow: Color
    var radius: CGFloat
    var buttonRadius: CGFloat
    var chipRadius: CGFloat
    var border: CGFloat
    var chipBorder: CGFloat
    var cardDrop: Drop
    var buttonDrop: Drop
    var bodyDesign: Font.Design
    var headingDesign: Font.Design
    var headingWeight: Font.Weight
    var highlight: Bool
    var sectionPill: Bool
    var uppercaseLabels: Bool
    var fx = PaperFX()

    func heading(_ size: CGFloat, _ weight: Font.Weight? = nil) -> Font {
        if let hand = fx.handFont {
            return .custom(hand, size: size * 1.05)
        }
        return .system(size: size, weight: weight ?? headingWeight, design: headingDesign)
    }

    func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: bodyDesign)
    }

    func label(_ text: String) -> String {
        uppercaseLabels ? text.uppercased() : text
    }
}

let paper = Color(red: 0.97, green: 0.95, blue: 0.90)
let red = Color(red: 1.0, green: 0.42, blue: 0.42)
let redSoft = Color(red: 1.0, green: 0.84, blue: 0.84)
let green = Color(red: 0.55, green: 0.90, blue: 0.55)
let greenSoft = Color(red: 0.84, green: 0.96, blue: 0.84)
let yellow = Color(red: 1.0, green: 0.87, blue: 0.40)
let charcoal = Color(red: 0.13, green: 0.12, blue: 0.14)
let cocoa = Color(red: 0.18, green: 0.13, blue: 0.11)

let current = Style(
    name: "0 Current",
    blurb: "radius 6 · border 2 · hard 4pt shadow everywhere",
    paper: paper, card: .white, ink: .black, muted: Color(white: 0.35),
    red: red, redSoft: redSoft, green: green, greenSoft: greenSoft, yellow: yellow,
    radius: 6, buttonRadius: 6, chipRadius: 4, border: 2, chipBorder: 1.5,
    cardDrop: .hard(4, .black), buttonDrop: .hard(4, .black),
    bodyDesign: .default, headingDesign: .default, headingWeight: .black,
    highlight: false, sectionPill: true, uppercaseLabels: true
)

let lighter = Style(
    name: "1 Lighter Neo",
    blurb: "radius 14 · border 1.5 · cards 2pt shadow · buttons 3pt · chips borderless",
    paper: paper, card: .white, ink: .black, muted: Color(white: 0.4),
    red: red, redSoft: redSoft, green: green, greenSoft: greenSoft, yellow: yellow,
    radius: 14, buttonRadius: 12, chipRadius: 8, border: 1.5, chipBorder: 0,
    cardDrop: .hard(2, .black), buttonDrop: .hard(3, .black),
    bodyDesign: .default, headingDesign: .default, headingWeight: .heavy,
    highlight: false, sectionPill: true, uppercaseLabels: true
)

let journal = Style(
    name: "2 Journal Ink",
    blurb: "mono headings · thin 1.25 strokes · flat cards · only buttons get 2pt shadow",
    paper: paper, card: .white, ink: .black, muted: Color(white: 0.45),
    red: red, redSoft: redSoft, green: green, greenSoft: greenSoft, yellow: yellow,
    radius: 12, buttonRadius: 12, chipRadius: 6, border: 1.25, chipBorder: 1,
    cardDrop: .none, buttonDrop: .hard(2, .black),
    bodyDesign: .default, headingDesign: .monospaced, headingWeight: .bold,
    highlight: false, sectionPill: false, uppercaseLabels: false
)

let mascot = Style(
    name: "3 Soft Mascot",
    blurb: "no borders · radius 20 · soft blur shadow · buttons get a darker 3pt lip + top highlight",
    paper: paper, card: .white, ink: charcoal, muted: Color(red: 0.45, green: 0.44, blue: 0.46),
    red: red, redSoft: redSoft, green: green, greenSoft: greenSoft, yellow: yellow,
    radius: 20, buttonRadius: 16, chipRadius: 8, border: 0, chipBorder: 0,
    cardDrop: .soft(radius: 12, y: 5, opacity: 0.12), buttonDrop: .lip(3),
    bodyDesign: .rounded, headingDesign: .rounded, headingWeight: .heavy,
    highlight: true, sectionPill: false, uppercaseLabels: false
)

let cartoon = Style(
    name: "4 Cartoon Sticker",
    blurb: "warm cocoa ink · border 2.5 · radius 18 · 3pt offset shadow · rounded type",
    paper: paper, card: .white, ink: cocoa, muted: Color(red: 0.45, green: 0.40, blue: 0.37),
    red: red, redSoft: redSoft, green: green, greenSoft: greenSoft, yellow: yellow,
    radius: 18, buttonRadius: 16, chipRadius: 99, border: 2.5, chipBorder: 2,
    cardDrop: .hard(3, cocoa), buttonDrop: .hard(3, cocoa),
    bodyDesign: .rounded, headingDesign: .rounded, headingWeight: .black,
    highlight: false, sectionPill: true, uppercaseLabels: false
)

let cartoonSoft = Style(
    name: "5 Cartoon Soft",
    blurb: "4 + 3: cocoa border 1.75 · radius 20 · 2pt offset shadow · top highlight on fills · chips radius 8, border 1.25",
    paper: paper, card: .white, ink: cocoa, muted: Color(red: 0.45, green: 0.40, blue: 0.37),
    red: red, redSoft: redSoft, green: green, greenSoft: greenSoft, yellow: yellow,
    radius: 20, buttonRadius: 16, chipRadius: 8, border: 1.75, chipBorder: 1.25,
    cardDrop: .hard(2, cocoa), buttonDrop: .hard(2.5, cocoa),
    bodyDesign: .rounded, headingDesign: .rounded, headingWeight: .black,
    highlight: true, sectionPill: true, uppercaseLabels: false
)

let cartoonSofter = Style(
    name: "5b Cartoon Softer",
    blurb: "same but cards get a blurred cocoa shadow and buttons get a same-hue lip instead of offset",
    paper: paper, card: .white, ink: cocoa, muted: Color(red: 0.45, green: 0.40, blue: 0.37),
    red: red, redSoft: redSoft, green: green, greenSoft: greenSoft, yellow: yellow,
    radius: 20, buttonRadius: 16, chipRadius: 8, border: 1.75, chipBorder: 1.25,
    cardDrop: .soft(radius: 6, y: 3, opacity: 0.18), buttonDrop: .lip(3),
    bodyDesign: .rounded, headingDesign: .rounded, headingWeight: .black,
    highlight: true, sectionPill: true, uppercaseLabels: false
)

let scrap = Color(red: 0.995, green: 0.99, blue: 0.965)
let warmPaper = Color(red: 0.96, green: 0.93, blue: 0.86)

let scratch = Style(
    name: "6 Scratchbook",
    blurb: "5 + paper grain, dot grid, taped tilted cards, pencil double outline, highlighter headers, stamp tags",
    paper: warmPaper, card: scrap, ink: cocoa, muted: Color(red: 0.45, green: 0.40, blue: 0.37),
    red: red, redSoft: redSoft, green: green, greenSoft: greenSoft, yellow: yellow,
    radius: 10, buttonRadius: 14, chipRadius: 6, border: 1.5, chipBorder: 1.25,
    cardDrop: .soft(radius: 3, y: 2, opacity: 0.16), buttonDrop: .hard(2.5, cocoa),
    bodyDesign: .rounded, headingDesign: .rounded, headingWeight: .black,
    highlight: false, sectionPill: true, uppercaseLabels: false,
    fx: PaperFX(grain: true, grid: .dots, tape: true, tilt: true, sketchy: true, highlighter: true, stamp: true)
)

let notebook = Style(
    name: "6b Notebook",
    blurb: "same but ruled lines, handwritten headings (Noteworthy), no tilt",
    paper: warmPaper, card: scrap, ink: cocoa, muted: Color(red: 0.45, green: 0.40, blue: 0.37),
    red: red, redSoft: redSoft, green: green, greenSoft: greenSoft, yellow: yellow,
    radius: 10, buttonRadius: 14, chipRadius: 6, border: 1.5, chipBorder: 1.25,
    cardDrop: .soft(radius: 3, y: 2, opacity: 0.16), buttonDrop: .hard(2.5, cocoa),
    bodyDesign: .rounded, headingDesign: .rounded, headingWeight: .black,
    highlight: false, sectionPill: true, uppercaseLabels: false,
    fx: PaperFX(grain: true, grid: .ruled, tape: true, tilt: false, sketchy: true, highlighter: true, stamp: true, handFont: "Noteworthy-Bold")
)

let styles = [current, lighter, journal, mascot, cartoon, cartoonSoft, cartoonSofter, scratch, notebook]
let compare = [cartoonSoft, scratch, notebook]

struct Seeded: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

struct PaperBackground: View {
    let s: Style

    var body: some View {
        ZStack {
            s.paper
            Canvas { ctx, size in
                switch s.fx.grid {
                case .dots:
                    var y: CGFloat = 10
                    while y < size.height {
                        var x: CGFloat = 10
                        while x < size.width {
                            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)), with: .color(s.ink.opacity(0.10)))
                            x += 22
                        }
                        y += 22
                    }
                case .ruled:
                    var y: CGFloat = 150
                    while y < size.height {
                        var line = Path()
                        line.move(to: CGPoint(x: 0, y: y))
                        line.addLine(to: CGPoint(x: size.width, y: y))
                        ctx.stroke(line, with: .color(s.ink.opacity(0.09)), lineWidth: 1)
                        y += 28
                    }
                    var margin = Path()
                    margin.move(to: CGPoint(x: 40, y: 0))
                    margin.addLine(to: CGPoint(x: 40, y: size.height))
                    ctx.stroke(margin, with: .color(s.red.opacity(0.35)), lineWidth: 1)
                case .none:
                    break
                }
                if s.fx.grain {
                    var rng = Seeded(state: 7)
                    for _ in 0..<9000 {
                        let x = CGFloat.random(in: 0..<size.width, using: &rng)
                        let y = CGFloat.random(in: 0..<size.height, using: &rng)
                        let a = Double.random(in: 0.03...0.09, using: &rng)
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.2, height: 1.2)), with: .color(s.ink.opacity(a)))
                    }
                }
            }
        }
    }
}

struct Tape: View {
    var angle: Double = -7

    var body: some View {
        Rectangle()
            .fill(Color(red: 1.0, green: 0.95, blue: 0.75).opacity(0.7))
            .overlay(Rectangle().strokeBorder(Color.white.opacity(0.5), lineWidth: 0.8))
            .frame(width: 46, height: 15)
            .rotationEffect(.degrees(angle))
            .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
    }
}

struct Surface: ViewModifier {
    let s: Style
    let fill: Color
    let radius: CGFloat
    let border: CGFloat
    let drop: Drop

    func body(content: Content) -> some View {
        content.background(backdrop)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    @ViewBuilder private var backdrop: some View {
        ZStack {
            switch drop {
            case .hard(let o, let c):
                shape.fill(c).offset(x: o, y: o)
            case .lip(let h):
                shape.fill(fill).overlay(shape.fill(Color.black.opacity(0.22))).offset(y: h)
            case .none, .soft:
                EmptyView()
            }
            face
        }
    }

    @ViewBuilder private var face: some View {
        let base = shape.fill(fill)
            .overlay {
                if s.highlight {
                    shape.fill(LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center))
                }
            }
            .overlay(shape.strokeBorder(s.ink, lineWidth: border))
            .overlay {
                if s.fx.sketchy, border > 0 {
                    shape.strokeBorder(s.ink.opacity(0.4), lineWidth: max(border * 0.6, 0.75))
                        .rotationEffect(.degrees(0.4))
                        .offset(x: 1.2, y: -0.8)
                }
            }
        if case .soft(let r, let y, let o) = drop {
            base.shadow(color: .black.opacity(o), radius: r, y: y)
        } else {
            base
        }
    }
}

extension View {
    func card(_ s: Style, _ fill: Color) -> some View {
        modifier(Surface(s: s, fill: fill, radius: s.radius, border: s.border, drop: s.cardDrop))
    }

    func chip(_ s: Style, _ fill: Color) -> some View {
        modifier(Surface(s: s, fill: fill, radius: s.chipRadius, border: s.chipBorder, drop: .none))
    }

    func iconButton(_ s: Style, _ fill: Color, size: CGFloat = 48) -> some View {
        font(.system(size: size * 0.42, weight: .bold, design: s.headingDesign))
            .foregroundStyle(s.ink)
            .frame(width: size, height: size)
            .modifier(Surface(s: s, fill: fill, radius: s.buttonRadius * (size / 48), border: s.border, drop: s.buttonDrop))
    }
}

struct Mood: View {
    let s: Style
    let symbol: String?
    var size: CGFloat = 24

    var body: some View {
        if let symbol {
            Image(systemName: symbol)
                .font(.system(size: size * 0.9, weight: .medium))
                .foregroundStyle(s.ink)
                .frame(width: size, height: size)
        } else {
            Circle()
                .strokeBorder(s.ink.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .frame(width: size, height: size)
        }
    }
}

struct HomeMock: View {
    let s: Style

    private let days: [(String, Int, String?, Bool)] = [
        ("M", 8, "face.smiling", false),
        ("T", 9, "face.smiling.inverse", false),
        ("W", 10, "face.dashed", false),
        ("T", 11, "face.smiling", false),
        ("F", 12, "face.smiling", false),
        ("S", 13, nil, false),
        ("S", 14, nil, true),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 14) {
                header
                week
                section("Today")
                row("Standup notes", "Talked about the BLE reconnect bug and how the transcription queue should retry.", "9:41 AM", audio: .done, mood: "face.smiling", tilt: -0.7)
                row("Idea: mood widget", "Small home screen widget that shows the week strip.", "8:02 AM", audio: nil, mood: nil, tilt: 0.5)
                section("Yesterday")
                row("Groceries + call mom", "Eggs, oat milk, the good bread. Call at 6.", "Yesterday", audio: .pending, mood: "face.dashed", tilt: 0.6)
                row("Walk thoughts", "The refactor should split the recorder from the link layer…", "Yesterday", audio: .done, mood: "face.smiling.inverse", tilt: -0.4)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 62)
            .frame(width: 393, height: 852, alignment: .top)
            .clipped()
            bottomBar
                .background(s.paper)
        }
        .frame(width: 393, height: 852)
        .background(PaperBackground(s: s))
        .clipShape(RoundedRectangle(cornerRadius: 52, style: .continuous))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Notes")
                    .font(s.heading(40))
                    .foregroundStyle(s.ink)
                Text("12 notes")
                    .font(s.body(15, .bold))
                    .foregroundStyle(s.muted)
            }
            Spacer()
            Image(systemName: "gearshape.fill")
                .iconButton(s, s.green)
        }
    }

    private var week: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "chevron.left").iconButton(s, s.card, size: 32)
                Text(s.label("This Week"))
                    .font(s.heading(13, .bold))
                    .foregroundStyle(s.ink)
                    .frame(maxWidth: .infinity)
                Image(systemName: "chevron.right").iconButton(s, s.card, size: 32).opacity(0.4)
            }
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    let d = days[i]
                    VStack(spacing: 3) {
                        Text(d.0)
                            .font(s.heading(11, .bold))
                            .foregroundStyle(s.muted)
                        Text("\(d.1)")
                            .font(s.heading(13, .heavy))
                            .foregroundStyle(s.ink)
                        Mood(s: s, symbol: d.2)
                            .opacity(i == 6 ? 0.25 : 1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .modifier(Surface(s: s, fill: d.3 ? s.yellow : s.card, radius: s.chipRadius == 99 ? 12 : s.chipRadius, border: s.chipBorder, drop: .none))
                }
            }
        }
        .padding(12)
        .card(s, s.greenSoft)
        .overlay(alignment: .top) {
            if s.fx.tape {
                Tape(angle: 3).offset(y: -7)
            }
        }
    }

    private func section(_ title: String) -> some View {
        Group {
            if s.fx.highlighter {
                Text(s.label(title))
                    .font(s.heading(14, .black))
                    .foregroundStyle(s.ink)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(s.yellow.opacity(0.85))
                            .rotationEffect(.degrees(-1.2))
                            .padding(.horizontal, -3)
                            .padding(.vertical, 3)
                    )
                    .padding(.leading, 4)
            } else if s.sectionPill {
                Text(s.label(title))
                    .font(s.heading(13, .black))
                    .foregroundStyle(s.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .chip(s, s.yellow)
            } else {
                Text(s.label(title))
                    .font(s.heading(13, .bold))
                    .foregroundStyle(s.muted)
                    .tracking(s.headingDesign == .monospaced ? 0 : 0.5)
                    .padding(.leading, 4)
            }
        }
        .padding(.top, 4)
    }

    enum Audio { case done, pending }

    private func row(_ title: String, _ preview: String, _ time: String, audio: Audio?, mood: String?, tilt: Double) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(s.heading(17, .heavy))
                    .foregroundStyle(s.ink)
                    .lineLimit(1)
                Text(preview)
                    .font(s.body(15))
                    .foregroundStyle(s.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    if s.fx.stamp {
                        Text(time)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(s.muted)
                        if let audio {
                            stamp("AUDIO", audio == .done ? s.green : s.yellow)
                        }
                    } else {
                        tag(time, s.chipBorder == 0 ? s.paper : s.card)
                        if let audio {
                            tag(s.label("Audio"), audio == .done ? s.green : s.yellow)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            if let mood {
                Mood(s: s, symbol: mood, size: 28)
                    .padding(4)
                    .modifier(Surface(s: s, fill: s.greenSoft, radius: s.chipRadius == 99 ? 12 : s.chipRadius, border: s.chipBorder, drop: .none))
            }
        }
        .padding(12)
        .card(s, s.card)
        .overlay(alignment: .topLeading) {
            if s.fx.tape {
                Tape(angle: tilt < 0 ? -8 : 6).offset(x: 14, y: -7)
            }
        }
        .rotationEffect(.degrees(s.fx.tilt ? tilt : 0))
    }

    private func stamp(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .tracking(1)
            .foregroundStyle(s.ink.opacity(0.85))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.55))
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(s.ink.opacity(0.85), lineWidth: 1.25))
            )
            .rotationEffect(.degrees(-3))
    }

    private func tag(_ text: String, _ fill: Color) -> some View {
        Text(text)
            .font(s.heading(12, .bold))
            .foregroundStyle(s.ink)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .chip(s, fill)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .bold))
                Text("Search")
                    .font(s.body(17, .semibold))
                    .foregroundStyle(s.muted)
                Spacer()
            }
            .foregroundStyle(s.ink)
            .padding(.horizontal, 12)
            .frame(height: 48)
            .card(s, s.card)
            Image(systemName: "photo.badge.plus").iconButton(s, s.yellow)
            Image(systemName: "square.and.pencil").iconButton(s, s.red)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 30)
    }
}

struct Sheet: View {
    let items: [Style]

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            ForEach(items, id: \.name) { s in
                VStack(alignment: .leading, spacing: 12) {
                    HomeMock(s: s)
                    Text(s.name)
                        .font(.system(size: 22, weight: .bold))
                    Text(s.blurb)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 393, alignment: .leading)
                }
            }
        }
        .foregroundStyle(.black)
        .padding(32)
        .background(Color(white: 0.92))
    }
}

@MainActor
func save(_ view: some View, to path: String, scale: CGFloat) {
    let renderer = ImageRenderer(content: view)
    renderer.scale = scale
    guard let image = renderer.cgImage else {
        fatalError("render failed for \(path)")
    }
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("cannot write \(path)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(path)")
}

MainActor.assumeIsolated {
    let outDir = CommandLine.arguments.dropFirst().first ?? "out"
    try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
    for s in styles {
        let file = s.name.lowercased().replacingOccurrences(of: " ", with: "-")
        save(HomeMock(s: s), to: "\(outDir)/\(file).png", scale: 2)
    }
    save(Sheet(items: styles), to: "\(outDir)/sheet.png", scale: 1.5)
    save(Sheet(items: compare), to: "\(outDir)/sheet-6.png", scale: 1.5)
}
