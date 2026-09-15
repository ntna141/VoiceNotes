import SwiftData
import SwiftUI

@main
struct VoiceNotesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    private let container: ModelContainer
    private let settings: AppSettings
    private let icons: MoodIconStore
    private let link: DeviceLink
    private let transcription: TranscriptionService

    init() {
        let schema = Schema([Note.self, DayMood.self, DayCanvas.self, CanvasItem.self])
        let inMemory = ProcessInfo.processInfo.arguments.contains("-seed")
        container = try! ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: inMemory, groupContainer: .none)])
        let context = container.mainContext
        settings = AppSettings()
        icons = MoodIconStore()
        link = DeviceLink(context: context, icons: icons)
        transcription = TranscriptionService(context: context, settings: settings)
        link.onRecordingFinished = { [transcription] note in
            transcription.enqueue(note)
        }
        transcription.registerBackgroundTasks()
        #if DEBUG
        if inMemory {
            SeedData.populate(context)
            if settings.vocabularyTerms.isEmpty {
                for term in ["Soniox", "XIAO", "Mai", "ADPCM"] {
                    settings.addTerm(term)
                }
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            NotesListView()
                .environment(settings)
                .environment(icons)
                .environment(link)
                .environment(transcription)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                transcription.appWillEnterForeground()
                Task { await container.mainContext.importSharedPhotos() }
            case .background:
                transcription.appDidEnterBackground()
            default:
                break
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        TranscriptionService.shared?.setBackgroundEventsHandler(completionHandler)
    }
}
