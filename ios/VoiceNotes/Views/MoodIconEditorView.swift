import PhotosUI
import SwiftUI

struct MoodIconEditorView: View {
    let mood: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(MoodIconStore.self) private var icons
    @Environment(DeviceLink.self) private var link
    @State private var mode = BitmapConverter.Mode.threshold
    @State private var source: UIImage?
    @State private var subject: UIImage?
    @State private var extractSubject = false
    @State private var extracting = false
    @State private var bitmap: [UInt8]?
    @State private var pickedItem: PhotosPickerItem?
    @State private var showingPicker = false
    @State private var conversionError: String?

    private var input: UIImage? {
        extractSubject ? (subject ?? source) : source
    }

    private var isDirty: Bool {
        guard let bitmap else { return false }
        return bitmap != icons.glyph(for: mood)
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
                rebuild()
            }
        }
        .onDisappear {
            persist()
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                persist()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(NeoIconButtonStyle(size: 40))
            .accessibilityLabel("Back")
            Text("Mood \(mood)")
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
            HStack(alignment: .bottom, spacing: 16) {
                BitmapGlyph(bitmap: previewBitmap, size: 208)
                    .padding(12)
                    .neoChip()
                VStack(spacing: 6) {
                    BitmapGlyph(bitmap: previewBitmap, size: 26)
                        .padding(4)
                        .neoChip()
                    Text("1:1")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Neo.muted)
                }
            }
            .frame(maxWidth: .infinity)
            HStack {
                NeoTag(text: isDirty ? "Unsaved" : (icons.isCustom(mood) ? "Custom" : "Default"), fill: isDirty ? Neo.yellow : Neo.greenSoft)
                Spacer()
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Group {
                    if let input {
                        Image(uiImage: input)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "photo")
                            .font(.title.weight(.bold))
                            .foregroundStyle(Neo.muted)
                    }
                }
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: Neo.chipRadius, style: .continuous))
                .neoChip()
                VStack(alignment: .leading, spacing: 10) {
                    Button(source == nil ? "Choose photo" : "Replace photo") {
                        showingPicker = true
                    }
                    .buttonStyle(NeoButtonStyle(fill: Neo.red, shadow: 2))
                    footer(source == nil ? "Pick a photo to convert it into a 26 by 26 icon." : "Conversion settings below are applied live.")
                }
                Spacer()
            }
            if let conversionError {
                Text(conversionError)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Neo.red)
            }
        }
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
            footer(extractSubject ? "The background is removed on device before converting." : "Threshold keeps flat shapes crisp. Dither preserves shading in photos.")
        }
        .disabled(source == nil)
        .opacity(source == nil ? 0.5 : 1)
    }

    private var previewBitmap: [UInt8] {
        bitmap ?? icons.glyph(for: mood) ?? MoodIcons.defaults[mood - 1]
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

    private func load(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
            conversionError = "Could not load that image"
            return
        }
        source = image.downscaled(maxSide: 1024)
        subject = nil
        conversionError = nil
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
        rebuild()
    }

    private func rebuild() {
        guard let input else {
            bitmap = nil
            return
        }
        if let converted = BitmapConverter.bitmap(from: input, mode: mode) {
            bitmap = converted
        } else {
            conversionError = "Could not convert that image"
        }
    }

    private func persist() {
        guard isDirty, let bitmap else { return }
        icons.setOverride(bitmap, for: mood)
        link.iconsChanged()
    }
}

struct BitmapGlyph: View {
    let bitmap: [UInt8]
    var size: CGFloat = 26

    var body: some View {
        if let image = BitmapConverter.image(from: bitmap) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .frame(width: size, height: size)
                .foregroundStyle(Neo.ink)
        } else {
            Color.clear
                .frame(width: size, height: size)
        }
    }
}
