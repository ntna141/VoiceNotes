import Foundation

enum SonioxError: LocalizedError {
    case missingAPIKey
    case http(Int, String)
    case badResponse
    case jobFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Add a Soniox API key in Settings"
        case .http(let code, let body): return "HTTP \(code): \(body.prefix(120))"
        case .badResponse: return "Unexpected response"
        case .jobFailed(let message): return message
        }
    }
}

enum SonioxJobStatus {
    case queued
    case completed
    case error(String)
}

struct SonioxClient {
    static let baseURL = URL(string: "https://api.soniox.com")!
    static let model = "stt-async-v5"

    let apiKey: String

    func uploadRequest() throws -> (URLRequest, boundary: String) {
        var request = try request(path: "/v1/files", method: "POST")
        let boundary = "VoiceNotes-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        return (request, boundary)
    }

    static func writeMultipart(wav: URL, boundary: String, to destination: URL) throws {
        let fileName = wav.lastPathComponent
        var head = Data()
        head.append(Data("--\(boundary)\r\n".utf8))
        head.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".utf8))
        head.append(Data("Content-Type: audio/wav\r\n\r\n".utf8))
        let tail = Data("\r\n--\(boundary)--\r\n".utf8)
        let audio = try Data(contentsOf: wav)
        var body = head
        body.append(audio)
        body.append(tail)
        try body.write(to: destination, options: .atomic)
    }

    func createRequest(fileId: String, terms: [String], languageHints: [String], reference: String) throws -> (URLRequest, Data) {
        var request = try request(path: "/v1/transcriptions", method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: Any] = [
            "model": Self.model,
            "file_id": fileId,
            "client_reference_id": reference,
        ]
        if !languageHints.isEmpty {
            payload["language_hints"] = languageHints
        }
        if !terms.isEmpty {
            payload["context"] = ["terms": terms]
        }
        let body = try JSONSerialization.data(withJSONObject: payload)
        return (request, body)
    }

    func status(transcriptionId: String) async throws -> SonioxJobStatus {
        let data = try await perform(try request(path: "/v1/transcriptions/\(transcriptionId)", method: "GET"))
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? String else {
            throw SonioxError.badResponse
        }
        switch status {
        case "completed":
            return .completed
        case "error":
            return .error(json["error_message"] as? String ?? "Transcription failed")
        default:
            return .queued
        }
    }

    func transcript(transcriptionId: String) async throws -> String {
        let data = try await perform(try request(path: "/v1/transcriptions/\(transcriptionId)/transcript", method: "GET"))
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [[String: Any]] else {
            throw SonioxError.badResponse
        }
        let text = tokens.compactMap { $0["text"] as? String }.joined()
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func delete(transcriptionId: String) async {
        _ = try? await perform(try request(path: "/v1/transcriptions/\(transcriptionId)", method: "DELETE"))
    }

    func deleteFile(fileId: String) async {
        _ = try? await perform(try request(path: "/v1/files/\(fileId)", method: "DELETE"))
    }

    static func parseId(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["id"] as? String
    }

    static func parseError(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (json["message"] as? String) ?? (json["error"] as? String) ?? (json["detail"] as? String)
    }

    private func request(path: String, method: String) throws -> URLRequest {
        guard !apiKey.isEmpty else { throw SonioxError.missingAPIKey }
        var request = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SonioxError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw SonioxError.http(http.statusCode, Self.parseError(data) ?? String(decoding: data, as: UTF8.self))
        }
        return data
    }
}
