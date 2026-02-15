import Foundation
import Supabase
import _Concurrency

/// Compact personalization context for parse-voice-tasks prompt injection
struct VoicePersonalization: Codable {
    let vocabularyAliases: [[String: String]]?  // top 10: [{"spoken": "Krogers", "canonical": "Kroger"}]
    let categoryMappings: [[String: String]]?   // top 10: [{"from": "Shopping", "to": "Groceries"}]
    let storeAliases: [[String: String]]?       // top 5: [{"spoken": "TJs", "canonical": "Trader Joe's"}]
    let timeHabits: [[String: String]]?         // top 5: [{"category": "Work", "pattern": "usually_has_time"}]
    
    enum CodingKeys: String, CodingKey {
        case vocabularyAliases = "vocabularyAliases"
        case categoryMappings = "categoryMappings"
        case storeAliases = "storeAliases"
        case timeHabits = "timeHabits"
    }
}

struct ParseRequest: Codable {
    let messages: [ConversationMessage]
    let today: String
    let timezone: String
    let contacts: [String]?
    let existingTasks: [TaskContext]?
    let groceryStores: [GroceryStoreContext]?
    let personalization: VoicePersonalization?
}

@Observable
@MainActor
class VoiceTaskParser {
    private let supabase = SupabaseConfig.client
    
    var isProcessing = false
    var errorMessage: String?
    /// Cached access token from last successful send(); passed to TTS to avoid redundant auth fetch.
    var lastAccessToken: String?
    /// Cached voice profile for session (prefetched on mic tap, used in send).
    private(set) var cachedProfile: VoicePersonalization?
    
    /// Prefetch voice profile from Supabase. Call when mic is tapped (runs in parallel with speech).
    /// Call with isEnabled: false when personalization is turned off.
    func fetchVoiceProfile(isEnabled: Bool = true) async -> VoicePersonalization? {
        guard isEnabled else {
            cachedProfile = nil
            return nil
        }
        do {
            struct VocabEntry: Codable {
                let spoken: String
                let canonical: String
            }
            struct CategoryMappingEntry: Codable {
                let from: String
                let to: String
            }
            struct StoreAliasEntry: Codable {
                let spoken: String
                let canonical: String
            }
            struct TimeHabitEntry: Codable {
                let category: String
                let pattern: String
            }
            struct ProfileRow: Codable {
                let vocabulary_aliases: [VocabEntry]?
                let category_mappings: [CategoryMappingEntry]?
                let store_aliases: [StoreAliasEntry]?
                let time_habits: [TimeHabitEntry]?
                let personalization_enabled: Bool?
            }
            let rows: [ProfileRow] = try await supabase
                .from("user_voice_profiles")
                .select("vocabulary_aliases, category_mappings, store_aliases, time_habits, personalization_enabled")
                .execute()
                .value
            guard let row = rows.first, row.personalization_enabled != false else {
                cachedProfile = nil
                return nil
            }
            let vocab = (row.vocabulary_aliases ?? []).prefix(10).map { ["spoken": $0.spoken, "canonical": $0.canonical] }
            let catMap = (row.category_mappings ?? []).prefix(10).map { ["from": $0.from, "to": $0.to] }
            let store = (row.store_aliases ?? []).prefix(5).map { ["spoken": $0.spoken, "canonical": $0.canonical] }
            let time = (row.time_habits ?? []).prefix(5).map { ["category": $0.category, "pattern": $0.pattern] }
            let profile = VoicePersonalization(
                vocabularyAliases: vocab.isEmpty ? nil : vocab,
                categoryMappings: catMap.isEmpty ? nil : catMap,
                storeAliases: store.isEmpty ? nil : store,
                timeHabits: time.isEmpty ? nil : time
            )
            cachedProfile = profile
            return profile
        } catch {
            cachedProfile = nil
            return nil
        }
    }
    
    func send(messages: [ConversationMessage], existingTasks: [TaskContext]? = nil, groceryStores: [GroceryStoreContext]? = nil, personalization: VoicePersonalization? = nil) async throws -> ParseResponse {
        try await sendStreaming(messages: messages, existingTasks: existingTasks, groceryStores: groceryStores, personalization: personalization, onResponse: nil)
    }
    
    /// Streaming variant: fires onResponse as soon as the full response is decoded so TTS can start immediately (overlaps with caller processing).
    func sendStreaming(messages: [ConversationMessage], existingTasks: [TaskContext]? = nil, groceryStores: [GroceryStoreContext]? = nil, personalization: VoicePersonalization? = nil, onResponse: ((ParseResponse) -> Void)? = nil) async throws -> ParseResponse {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let timezone = TimeZone.current.identifier
        let personalizationToUse = personalization ?? cachedProfile
        
        let requestBody = ParseRequest(
            messages: messages,
            today: String(today),
            timezone: timezone,
            contacts: nil,
            existingTasks: existingTasks,
            groceryStores: groceryStores,
            personalization: personalizationToUse
        )
        
        let session = try await supabase.auth.session
        lastAccessToken = session.accessToken
        
        guard let url = URL(string: "\(SupabaseConfig.urlString)/functions/v1/parse-voice-tasks") else {
            throw NSError(domain: "VoiceTaskParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid parse URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "VoiceTaskParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            var errorData = Data()
            for try await byte in bytes { errorData.append(byte) }
            let errorBody = String(data: errorData, encoding: .utf8) ?? ""
            if let errData = errorBody.data(using: .utf8),
               let err = try? JSONDecoder().decode([String: String].self, from: errData),
               let msg = err["error"] {
                errorMessage = msg
                throw NSError(domain: "VoiceTaskParser", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            errorMessage = "Server error (\(httpResponse.statusCode))"
            throw NSError(domain: "VoiceTaskParser", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error (\(httpResponse.statusCode))"])
        }
        
        // Consume SSE stream and accumulate content
        var buffer = ""
        var aiContent = ""
        for try await byte in bytes {
            buffer.append(Character(Unicode.Scalar(byte)))
            let lines = buffer.split(separator: "\n", omittingEmptySubsequences: false)
            buffer = String(lines.last ?? Substring())
            for line in lines.dropLast() {
                let s = String(line)
                if s.hasPrefix("data: ") {
                    let data = String(s.dropFirst(6))
                    if data == "[DONE]" { continue }
                    if let jsonData = data.data(using: .utf8),
                       let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let choices = parsed["choices"] as? [[String: Any]],
                       let first = choices.first,
                       let delta = first["delta"] as? [String: Any],
                       let content = delta["content"] as? String {
                        aiContent += content
                    }
                }
            }
        }
        
        guard !aiContent.isEmpty else {
            errorMessage = "Invalid AI response"
            throw NSError(domain: "VoiceTaskParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid AI response"])
        }
        
        let parseResponse = try Self.normalizeAndDecode(aiContent: aiContent, onResponse: onResponse)
        
        #if DEBUG
        print("[VoiceTaskParser] Response — type: \(parseResponse.type), taskId: \(parseResponse.taskId ?? "nil"), summary: \(parseResponse.summary ?? "nil"), text: \(parseResponse.text ?? "nil"), tasks: \(parseResponse.tasks?.count ?? 0), changes: \(parseResponse.changes != nil ? "present" : "nil")")
        #endif
        
        return parseResponse
    }
    
    /// Decode raw AI JSON, apply normalization (valid types, task IDs), and optionally fire onResponse for TTS overlap.
    private static func normalizeAndDecode(aiContent: String, onResponse: ((ParseResponse) -> Void)?) throws -> ParseResponse {
        guard let jsonData = aiContent.data(using: .utf8) else {
            throw NSError(domain: "VoiceTaskParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid AI response encoding"])
        }
        
        var json = (try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]) ?? [:]
        
        // Ensure task IDs
        if var tasks = json["tasks"] as? [[String: Any]] {
            for i in tasks.indices {
                if tasks[i]["id"] == nil {
                    tasks[i]["id"] = UUID().uuidString
                }
            }
            json["tasks"] = tasks
        }
        
        // Normalize invalid type to question
        let validTypes = ["question", "complete", "update", "delete"]
        if !validTypes.contains(json["type"] as? String ?? "") {
            json["type"] = "question"
            json["text"] = json["text"] ?? json["summary"] ?? json["message"] ?? json["response"] ?? "What would you like to do?"
            json["tasks"] = nil
            json["taskId"] = nil
            json["changes"] = nil
            json["summary"] = nil
        }
        
        let normalizedData = try JSONSerialization.data(withJSONObject: json)
        let response = try JSONDecoder().decode(ParseResponse.self, from: normalizedData)
        
        // Fire onResponse immediately so TTS can start while caller processes tasks
        onResponse?(response)
        
        return response
    }
    
    /// Transcribes audio using Whisper API via Edge Function
    func transcribe(audioData: Data) async throws -> String {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        
        // Encode audio as base64
        let base64Audio = audioData.base64EncodedString()
        
        struct TranscribeRequest: Codable {
            let audio: String
        }
        
        struct TranscribeResponse: Codable {
            let text: String
        }
        
        do {
            let session = try await supabase.auth.session
            
            let response: TranscribeResponse = try await supabase.functions.invoke(
                "transcribe-audio",
                options: FunctionInvokeOptions(
                    headers: ["Authorization": "Bearer \(session.accessToken)"],
                    body: TranscribeRequest(audio: base64Audio)
                )
            )
            
            return response.text
        } catch let error as FunctionsError {
            switch error {
            case .httpError(let code, let data):
                let body = String(data: data, encoding: .utf8) ?? "(no body)"
                print("[VoiceTaskParser] Whisper HTTP \(code): \(body)")
                errorMessage = "Transcription error (\(code))"
            case .relayError:
                print("[VoiceTaskParser] Whisper relay error")
                errorMessage = "Transcription service unavailable"
            }
            throw error
        } catch {
            print("[VoiceTaskParser] Whisper error: \(error)")
            errorMessage = "Failed to transcribe audio: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Fire-and-forget: record corrections for voice personalization learning
    func recordCorrections(_ corrections: [CorrectionEntry]) {
        guard !corrections.isEmpty else { return }
        _Concurrency.Task {
            do {
                let session = try await supabase.auth.session
                struct RecordRequest: Codable {
                    let corrections: [CorrectionEntry]
                }
                _ = try await supabase.functions.invoke(
                    "record-corrections",
                    options: FunctionInvokeOptions(
                        headers: ["Authorization": "Bearer \(session.accessToken)"],
                        body: RecordRequest(corrections: corrections)
                    )
                )
            } catch {
                print("[VoiceTaskParser] recordCorrections failed: \(error)")
            }
        }
    }
}
