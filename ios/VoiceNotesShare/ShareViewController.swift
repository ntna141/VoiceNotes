import SwiftUI
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Neo.paper)
        let host = UIHostingController(rootView: DayPickerCard { [weak self] dayKey in
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
