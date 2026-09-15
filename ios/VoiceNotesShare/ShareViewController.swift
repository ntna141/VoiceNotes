import SwiftUI
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Neo.paper)
        let host = UIHostingController(rootView: ShareDayPicker { [weak self] dayKey in
            self?.finish(dayKey: dayKey)
        } onCancel: { [weak self] in
            self?.extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
        })
        host.view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.didMove(toParent: self)
    }

    private func finish(dayKey: String) {
        Task {
            await importAttachments(dayKey: dayKey)
            extensionContext?.completeRequest(returningItems: nil)
        }
    }

    private func importAttachments(dayKey: String) async {
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        for provider in items.flatMap({ $0.attachments ?? [] }) where provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            if let data = await provider.imageData() {
                CanvasInbox.store(data, dayKey: dayKey)
            }
        }
    }
}

struct ShareDayPicker: View {
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

extension NSItemProvider {
    func imageData() async -> Data? {
        guard let item = try? await loadItem(forTypeIdentifier: UTType.image.identifier) else { return nil }
        switch item {
        case let url as URL:
            return try? Data(contentsOf: url)
        case let data as Data:
            return data
        case let image as UIImage:
            return image.pngData()
        default:
            return nil
        }
    }
}
