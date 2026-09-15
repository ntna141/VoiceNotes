import Foundation
import Synchronization

struct BackgroundTaskResult: Sendable {
    let description: String
    let statusCode: Int?
    let body: Data
    let error: String?
}

nonisolated final class BackgroundSessionDelegate: NSObject, URLSessionDataDelegate, Sendable {
    private let buffers = Mutex<[Int: Data]>([:])
    private let onComplete: @Sendable (BackgroundTaskResult) -> Void
    private let onFinishEvents: @Sendable () -> Void

    init(onComplete: @escaping @Sendable (BackgroundTaskResult) -> Void, onFinishEvents: @escaping @Sendable () -> Void) {
        self.onComplete = onComplete
        self.onFinishEvents = onFinishEvents
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffers.withLock { $0[dataTask.taskIdentifier, default: Data()].append(data) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let body = buffers.withLock { $0.removeValue(forKey: task.taskIdentifier) } ?? Data()
        let result = BackgroundTaskResult(
            description: task.taskDescription ?? "",
            statusCode: (task.response as? HTTPURLResponse)?.statusCode,
            body: body,
            error: error?.localizedDescription
        )
        onComplete(result)
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        onFinishEvents()
    }
}
