import PhotosUI
import SwiftData
import SwiftUI

struct DayCanvasView: View {
    @State private var dayKey: String

    init(dayKey: String) {
        _dayKey = State(initialValue: dayKey)
    }

    var body: some View {
        DayCanvasPage(dayKey: dayKey)
            .id(dayKey)
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
    }

    private var bottomBar: some View {
        HStack(spacing: 16) {
            dayButton(offset: -1)
            dayButton(offset: 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 9)
        .background(Neo.paper.opacity(0.95).ignoresSafeArea())
    }

    private func dayButton(offset: Int) -> some View {
        let target = DayKey.shifted(dayKey, by: offset) ?? dayKey
        let allowed = target <= DayKey.today
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                dayKey = target
            }
        } label: {
            Image(systemName: offset < 0 ? "chevron.left" : "chevron.right")
        }
        .buttonStyle(NeoIconButtonStyle(size: 40))
        .disabled(!allowed)
        .opacity(allowed ? 1 : 0.4)
        .accessibilityLabel(offset < 0 ? "Previous day" : "Next day")
    }
}

struct IdentifiedImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct DayCanvasPage: View {
    let dayKey: String

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var items: [CanvasItem]
    @Query private var canvases: [DayCanvas]
    @State private var images: [String: UIImage] = [:]
    @State private var zoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @GestureState private var pinch = PinchState()
    @GestureState private var livePan: CGSize = .zero
    @State private var showingPicker = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var pendingPhoto: IdentifiedImage?
    @State private var showingPaper = false
    @State private var snapshot: IdentifiedImage?
    @State private var extracting: Set<UUID> = []

    private struct PinchState {
        var magnification: CGFloat = 1
        var anchor: UnitPoint = .center
    }

    init(dayKey: String) {
        self.dayKey = dayKey
        _items = Query(filter: #Predicate<CanvasItem> { $0.dayKey == dayKey }, sort: \CanvasItem.createdAt)
        _canvases = Query(filter: #Predicate<DayCanvas> { $0.dayKey == dayKey })
    }

    private var placed: [CanvasItem] {
        items.filter(\.isPlaced)
    }

    private var paper: CanvasPaper {
        canvases.first?.paper ?? .cream
    }

    private var pattern: CanvasPattern {
        canvases.first?.pattern ?? .plain
    }

    private var title: String {
        DayKey.shortLabel(dayKey)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(16)
            GeometryReader { proxy in
                let container = CanvasPage.fitted(in: proxy.size)
                page(container: container)
                    .frame(width: container.width, height: container.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 11)
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
        .sheet(item: $pendingPhoto) { photo in
            CanvasPhotoSheet(source: photo.image) { source, cutout in
                add(source, cutout: cutout)
            }
        }
        .sheet(isPresented: $showingPaper) {
            paperSheet
        }
        .sheet(item: $snapshot) { snapshot in
            ShareSheet(items: [snapshot.image])
                .presentationDetents([.medium, .large])
        }
        .task(id: items.count) {
            await loadImages()
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
            Text(title)
                .font(.headline.weight(.black))
                .foregroundStyle(Neo.ink)
                .lineLimit(1)
            Spacer()
            Button {
                showingPaper = true
            } label: {
                Image(systemName: "paintpalette.fill")
            }
            .buttonStyle(NeoIconButtonStyle(fill: paper.color, size: 40))
            .accessibilityLabel("Background")
            Button {
                showingPicker = true
            } label: {
                Image(systemName: "photo.badge.plus")
            }
            .buttonStyle(NeoIconButtonStyle(fill: Neo.yellow, size: 40))
            .accessibilityLabel("Add photo")
            Button {
                share()
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(NeoIconButtonStyle(fill: Neo.green, size: 40))
            .disabled(placed.isEmpty)
            .opacity(placed.isEmpty ? 0.5 : 1)
            .accessibilityLabel("Share")
        }
    }

    private func page(container: CGSize) -> some View {
        let live = transform(magnification: pinch.magnification, anchor: pinch.anchor, extra: livePan, container: container)
        return pageContent(images: images)
            .coordinateSpace(.named(CanvasPage.space))
            .scaleEffect(live.zoom * container.width / CanvasPage.size.width)
            .offset(live.pan)
            .frame(width: container.width, height: container.height)
            .clipShape(RoundedRectangle(cornerRadius: Neo.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Neo.radius, style: .continuous).strokeBorder(Neo.ink, lineWidth: 3))
            .overlay {
                if placed.isEmpty {
                    Text("Tap + to add a photo")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Neo.muted)
                        .allowsHitTesting(false)
                }
            }
            .gesture(pageGestures(container: container))
            .onTapGesture(count: 2) {
                withAnimation(.easeOut(duration: 0.2)) {
                    zoom = 1
                    pan = .zero
                }
            }
    }

    private func pageContent(images: [String: UIImage]) -> some View {
        CanvasPageContent(paper: paper, pattern: pattern, items: placed) { item in
            CanvasItemView(item: item, image: images[item.displayFileName], busy: extracting.contains(item.id)) {
                raise(item)
            } onCommit: {
                save()
            } onToggleCutout: {
                toggleCutout(item)
            } onDelete: {
                item.isPlaced = false
                save()
            }
        }
    }

    private func pageGestures(container: CGSize) -> some Gesture {
        let magnify = MagnifyGesture()
            .updating($pinch) { value, state, _ in
                state.magnification = value.magnification
                state.anchor = value.startAnchor
            }
            .onEnded { value in
                let result = transform(magnification: value.magnification, anchor: value.startAnchor, extra: .zero, container: container)
                zoom = result.zoom
                pan = result.pan
            }
        let drag = DragGesture(minimumDistance: 8)
            .updating($livePan) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                pan = transform(magnification: 1, anchor: .center, extra: value.translation, container: container).pan
            }
        return magnify.simultaneously(with: drag)
    }

    private func transform(magnification: CGFloat, anchor: UnitPoint, extra: CGSize, container: CGSize) -> (zoom: CGFloat, pan: CGSize) {
        let target = min(max(zoom * magnification, 1), 3)
        let ratio = target / zoom
        let ax = (anchor.x - 0.5) * container.width
        let ay = (anchor.y - 0.5) * container.height
        let limitX = container.width * (target - 1) / 2
        let limitY = container.height * (target - 1) / 2
        let x = ax - (ax - pan.width) * ratio + extra.width
        let y = ay - (ay - pan.height) * ratio + extra.height
        return (target, CGSize(width: min(max(x, -limitX), limitX), height: min(max(y, -limitY), limitY)))
    }

    private var paperSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            NeoSectionHeader(title: "Paper")
            HStack(spacing: 10) {
                ForEach(CanvasPaper.allCases) { option in
                    Button {
                        setPaper(option)
                    } label: {
                        NeoSurface(fill: option.color, radius: Neo.chipRadius, border: option == paper ? 3 : Neo.chipBorder)
                            .frame(height: 40)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Paper \(option.rawValue + 1)")
                }
            }
            NeoSectionHeader(title: "Pattern")
            HStack(spacing: 12) {
                ForEach(CanvasPattern.allCases) { option in
                    Button {
                        setPattern(option)
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                paper.color
                                CanvasPatternView(pattern: option, step: 14)
                            }
                            .frame(width: 72, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: Neo.chipRadius, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Neo.chipRadius, style: .continuous).strokeBorder(Neo.ink, lineWidth: option == pattern ? 3 : Neo.chipBorder))
                            Text(option.label)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Neo.ink)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            if !items.isEmpty {
                NeoSectionHeader(title: "Assets")
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(items) { item in
                            assetChip(item, cutout: false)
                            if item.cutoutFileName != nil {
                                assetChip(item, cutout: true)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.trailing, Neo.shadow)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, -20)
                .contentMargins(.horizontal, 20, for: .scrollContent)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.height(items.isEmpty ? 260 : 400)])
        .presentationBackground(Neo.paper)
    }

    private func assetChip(_ item: CanvasItem, cutout: Bool) -> some View {
        let fileName = cutout ? item.cutoutFileName ?? item.fileName : item.fileName
        let aspect = cutout ? item.cutoutAspect : item.aspect
        let inset = cutout ? 0 : CanvasPage.padding * 2
        let active = item.isPlaced && item.isCutout == cutout
        return Button {
            place(item, cutout: cutout)
        } label: {
            ScrapView(image: images[fileName], isCutout: cutout)
                .frame(width: (72 - inset) * aspect + inset, height: 72)
                .opacity(item.isPlaced ? 1 : 0.55)
                .overlay(alignment: .bottomTrailing) {
                    if active {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(Neo.ink)
                            .frame(width: 20, height: 20)
                            .background(NeoSurface(fill: Neo.green, radius: 10))
                            .offset(x: 6, y: 6)
                    }
                }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete", systemImage: "trash", role: .destructive) {
                deleteAsset(item, cutout: cutout)
            }
        }
    }

    private func setPaper(_ option: CanvasPaper) {
        context.canvas(for: dayKey).paper = option
        save()
    }

    private func setPattern(_ option: CanvasPattern) {
        context.canvas(for: dayKey).pattern = option
        save()
    }

    private func load(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
        pendingPhoto = IdentifiedImage(image: image.downscaled(maxSide: 1536))
    }

    private func loadImages() async {
        for fileName in items.flatMap(\.fileNames) where images[fileName] == nil {
            if let image = await PhotoStore.load(fileName) {
                images[fileName] = image
            }
        }
    }

    private func add(_ source: UIImage, cutout: UIImage?) {
        Task {
            guard let item = await context.addCanvasItem(dayKey: dayKey, source: source, cutout: cutout, spread: CGSize(width: 20, height: 30)) else { return }
            images[item.fileName] = source
            if let cutout, let cutoutName = item.cutoutFileName {
                images[cutoutName] = cutout
            }
            save()
        }
    }

    private func place(_ item: CanvasItem, cutout: Bool) {
        if item.isPlaced, item.isCutout == cutout {
            item.isPlaced = false
        } else {
            item.isCutout = cutout
            if item.isPlaced {
                raise(item)
            } else {
                item.isPlaced = true
                item.z = context.nextZ(for: dayKey)
            }
        }
        save()
    }

    private func deleteAsset(_ item: CanvasItem, cutout: Bool) {
        if cutout, let cutoutName = item.cutoutFileName {
            PhotoStore.remove(cutoutName)
            images[cutoutName] = nil
            item.cutoutFileName = nil
            item.isCutout = false
        } else {
            for fileName in item.fileNames {
                PhotoStore.remove(fileName)
                images[fileName] = nil
            }
            context.delete(item)
        }
        save()
    }

    private func toggleCutout(_ item: CanvasItem) {
        if item.isCutout || item.cutoutFileName != nil {
            item.isCutout.toggle()
            save()
            return
        }
        guard let source = images[item.fileName], !extracting.contains(item.id) else { return }
        extracting.insert(item.id)
        Task {
            defer { extracting.remove(item.id) }
            guard let cutout = await SubjectExtractor.extract(from: source),
                  let sticker = await PhotoStore.sticker(cutout),
                  let cutoutName = await PhotoStore.save(sticker, cutout: true)
            else { return }
            images[cutoutName] = sticker
            item.setCutout(fileName: cutoutName, aspect: sticker.size.width / sticker.size.height)
            save()
        }
    }

    private func raise(_ item: CanvasItem) {
        let top = placed.map(\.z).max() ?? 0
        if item.z != top || placed.filter({ $0.z == top }).count > 1 {
            item.z = top + 1
        }
    }

    private func save() {
        try? context.save()
    }

    private func share() {
        let renderer = ImageRenderer(content: pageContent(images: images))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(CanvasPage.size)
        guard let image = renderer.uiImage else { return }
        snapshot = IdentifiedImage(image: image)
    }
}

struct CanvasPhotoSheet: View {
    let source: UIImage
    let onAdd: (UIImage, UIImage?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var extract = false
    @State private var subject: UIImage?
    @State private var extracting = false
    @State private var error: String?

    private var preview: UIImage {
        extract ? (subject ?? source) : source
    }

    private var isCutout: Bool {
        extract && subject != nil
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Add photo")
                    .font(.title2.weight(.black))
                    .foregroundStyle(Neo.ink)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(NeoButtonStyle())
            }
            ScrapView(image: preview, isCutout: isCutout)
                .aspectRatio(preview.size.width / preview.size.height, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.trailing, Neo.shadow)
            Toggle(isOn: $extract) {
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
            if let error {
                Text(error)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Neo.red)
            }
            Button {
                onAdd(source, isCutout ? subject : nil)
                dismiss()
            } label: {
                Text("Add to page")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(NeoButtonStyle(fill: Neo.green))
            .disabled(extracting)
            .opacity(extracting ? 0.5 : 1)
        }
        .padding(20)
        .padding(.trailing, Neo.shadow)
        .presentationBackground(Neo.paper)
        .onChange(of: extract) {
            if extract, subject == nil {
                Task { await runExtraction() }
            }
        }
    }

    private func runExtraction() async {
        extracting = true
        defer { extracting = false }
        if let cutout = await SubjectExtractor.extract(from: source), let sticker = await PhotoStore.sticker(cutout) {
            subject = sticker
            error = nil
        } else {
            extract = false
            error = "No subject found in that photo"
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
