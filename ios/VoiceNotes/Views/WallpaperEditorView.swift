import PhotosUI
import SwiftUI

struct WallpaperEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WallpaperStore.self) private var wallpaper
    @Environment(DeviceLink.self) private var link
    @State private var mode = BitmapConverter.Mode.dither
    @State private var source: UIImage?
    @State private var subject: UIImage?
    @State private var extractSubject = false
    @State private var extracting = false
    @State private var bitmap: [UInt8]?
    @State private var pickedItem: PhotosPickerItem?
    @State private var showingPicker = false
    @State private var conversionError: String?
    @State private var zoom: CGFloat = 1
    @State private var offset = CGSize.zero
    @State private var baseZoom: CGFloat = 1
    @State private var baseOffset = CGSize.zero

    private let viewport: CGFloat = 280
    private let maxZoom: CGFloat = 6

    private var input: UIImage? {
        extractSubject ? (subject ?? source) : source
    }

    private var isDirty: Bool {
        guard let bitmap else { return false }
        return bitmap != wallpaper.bitmap
    }

    private var pixelSize: CGSize {
        guard let cg = input?.cgImage else { return .zero }
        return CGSize(width: cg.width, height: cg.height)
    }

    private var minZoom: CGFloat {
        let size = pixelSize
        guard size.width > 0, size.height > 0 else { return 1 }
        return min(size.width, size.height) / max(size.width, size.height)
    }

    private var displayScale: CGFloat {
        let size = pixelSize
        guard size.width > 0, size.height > 0 else { return 1 }
        return zoom * viewport / min(size.width, size.height)
    }

    private var crop: CGRect {
        let size = pixelSize
        let s = displayScale
        let side = viewport / s
        return CGRect(
            x: size.width / 2 - (viewport / 2 + offset.width) / s,
            y: size.height / 2 - (viewport / 2 + offset.height) / s,
            width: side,
            height: side
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(16)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section("Preview") { previewSection }
                    section("Photo") { photoSection }
                    section("Conversion") { conversionSection }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .background(Neo.paper.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .tint(Neo.ink)
        .photosPicker(isPresented: $showingPicker, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task {
                await load(item)
                pickedItem = nil
            }
        }
        .onChange(of: mode) {
            rebuild()
        }
        .onChange(of: extractSubject) {
            if extractSubject, subject == nil, source != nil {
                Task { await runExtraction() }
            } else {
                resetCrop()
                rebuild()
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(NeoIconButtonStyle(size: 40))
            .accessibilityLabel("Back")
            Text("Wallpaper")
                .font(.title.weight(.black))
                .foregroundStyle(Neo.ink)
            Spacer()
            Button("Save") {
                persist()
            }
            .buttonStyle(NeoButtonStyle(fill: Neo.green))
            .disabled(!isDirty)
            .opacity(isDirty ? 1 : 0.5)
        }
    }

    private var previewSection: some View {
        VStack(spacing: 12) {
            Group {
                if let previewBitmap {
                    BitmapGlyph(bitmap: previewBitmap, size: CGFloat(WallpaperStore.size), pixels: WallpaperStore.size)
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Neo.muted)
                        .frame(width: CGFloat(WallpaperStore.size), height: CGFloat(WallpaperStore.size))
                }
            }
            .padding(12)
            .neoChip()
            .frame(maxWidth: .infinity)
            HStack {
                NeoTag(text: isDirty ? "Unsaved" : (wallpaper.bitmap == nil ? "None" : "On device"), fill: isDirty ? Neo.yellow : Neo.greenSoft)
                Spacer()
                Text("\(WallpaperStore.size) x \(WallpaperStore.size)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Neo.muted)
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let input {
                cropView(input)
                    .frame(maxWidth: .infinity)
                footer("Pinch to zoom, drag to move. The square is what the device shows.")
            }
            HStack(spacing: 10) {
                Button(source == nil ? "Choose photo" : "Replace photo") {
                    showingPicker = true
                }
                .buttonStyle(NeoButtonStyle(fill: Neo.red, shadow: 2))
                if source != nil, zoom != 1 || offset != .zero {
                    Button("Recenter") {
                        resetCrop()
                        rebuild()
                    }
                    .buttonStyle(NeoButtonStyle(fill: Neo.card, shadow: 2))
                }
            }
            if source == nil {
                footer("Pick a photo to convert it into a \(WallpaperStore.size) by \(WallpaperStore.size) wallpaper.")
            }
            if let conversionError {
                Text(conversionError)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Neo.red)
            }
        }
    }

    private func cropView(_ image: UIImage) -> some View {
        let size = pixelSize
        let s = displayScale
        let drag = DragGesture()
            .onChanged { value in
                offset = clamped(CGSize(width: baseOffset.width + value.translation.width, height: baseOffset.height + value.translation.height))
            }
            .onEnded { _ in
                baseOffset = offset
                rebuild()
            }
        let magnify = MagnifyGesture()
            .onChanged { value in
                zoom = min(maxZoom, max(minZoom, baseZoom * value.magnification))
                offset = clamped(offset)
            }
            .onEnded { _ in
                baseZoom = zoom
                baseOffset = offset
                rebuild()
            }
        return Image(uiImage: image)
            .resizable()
            .frame(width: size.width * s, height: size.height * s)
            .offset(offset)
            .frame(width: viewport, height: viewport)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Neo.chipRadius, style: .continuous))
            .neoChip()
            .contentShape(Rectangle())
            .gesture(drag.simultaneously(with: magnify))
    }

    private var conversionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Conversion", selection: $mode) {
                ForEach(BitmapConverter.Mode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Toggle(isOn: $extractSubject) {
                HStack(spacing: 8) {
                    Text("Extract main subject")
                        .font(.body.weight(.bold))
                        .foregroundStyle(Neo.ink)
                    if extracting {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .tint(Neo.green)
            footer(extractSubject ? "The background is removed on device before converting." : "Dither preserves shading in photos. Threshold keeps flat shapes crisp. Outline traces edges, best for line drawings on paper.")
        }
        .disabled(source == nil)
        .opacity(source == nil ? 0.5 : 1)
    }

    private var previewBitmap: [UInt8]? {
        bitmap ?? wallpaper.bitmap
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            NeoSectionHeader(title: title)
            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .neoCard()
        }
        .padding(.trailing, Neo.shadow)
    }

    private func footer(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Neo.muted)
    }

    private func clamped(_ candidate: CGSize) -> CGSize {
        let size = pixelSize
        let s = displayScale
        func axis(_ value: CGFloat, _ length: CGFloat) -> CGFloat {
            let limit = max(0, (length * s - viewport) / 2)
            return min(limit, max(-limit, value))
        }
        return CGSize(width: axis(candidate.width, size.width), height: axis(candidate.height, size.height))
    }

    private func resetCrop() {
        zoom = 1
        offset = .zero
        baseZoom = 1
        baseOffset = .zero
    }

    private func load(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
            conversionError = "Could not load that image"
            return
        }
        source = image.downscaled(maxSide: 1024)
        subject = nil
        conversionError = nil
        resetCrop()
        if extractSubject {
            await runExtraction()
        } else {
            rebuild()
        }
    }

    private func runExtraction() async {
        guard let source else { return }
        extracting = true
        defer { extracting = false }
        if let result = await SubjectExtractor.extract(from: source) {
            subject = result
            conversionError = nil
        } else {
            extractSubject = false
            conversionError = "No subject found in that photo"
        }
        resetCrop()
        rebuild()
    }

    private func rebuild() {
        guard let input else {
            bitmap = nil
            return
        }
        if let converted = BitmapConverter.bitmap(from: input, size: WallpaperStore.size, crop: crop, mode: mode) {
            bitmap = converted
        } else {
            conversionError = "Could not convert that image"
        }
    }

    private func persist() {
        guard isDirty, let bitmap else { return }
        wallpaper.set(bitmap)
        link.wallpaperChanged()
    }
}
