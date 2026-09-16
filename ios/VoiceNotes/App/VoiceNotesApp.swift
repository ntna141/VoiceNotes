import SwiftData
import SwiftUI

@main
struct VoiceNotesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            NotesListView()
                .environment(appDelegate.settings)
                .environment(appDelegate.icons)
                .environment(appDelegate.link)
                .environment(appDelegate.transcription)
        }
        .modelContainer(appDelegate.container)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                appDelegate.transcription.appWillEnterForeground()
                Task { await appDelegate.container.mainContext.importSharedPhotos() }
            case .background:
                appDelegate.transcription.appDidEnterBackground()
            default:
                break
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    let container: ModelContainer
    let settings: AppSettings
    let icons: MoodIconStore
    let link: DeviceLink
    let transcription: TranscriptionService

    override init() {
        let schema = Schema([Note.self, DayMood.self, DayCanvas.self, CanvasItem.self])
        let inMemory = ProcessInfo.processInfo.arguments.contains("-seed")
        container = try! ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: inMemory, groupContainer: .none)])
        let context = container.mainContext
        settings = AppSettings()
        icons = MoodIconStore()
        link = DeviceLink(context: context, icons: icons)
        transcription = TranscriptionService(context: context, settings: settings)
        super.init()
        link.onRecordingFinished = { [transcription] note in
            transcription.enqueue(note)
        }
        transcription.registerBackgroundTasks()
        CameraSession.shared.prewarm()
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

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        transcription.setBackgroundEventsHandler(completionHandler)
    }
}
