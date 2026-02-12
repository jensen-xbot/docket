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
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        
        // Format today's date as yyyy-MM-dd
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let timezone = TimeZone.current.identifier
        
        // Use passed personalization or cached (from prefetch)
        let personalizationToUse = personalization ?? cachedProfile
        
        // Build request body
        let requestBody = ParseRequest(
            messages: messages,
            today: String(today),
            timezone: timezone,
            contacts: nil,
            existingTasks: existingTasks,
            groceryStores: groceryStores,
            personalization: personalizationToUse
        )
        
        do {
            // Get a fresh session and explicitly pass the JWT token.
            // The SDK's automatic auth sometimes doesn't match the
            // Edge Functions gateway's JWT verification format.
            let session = try await supabase.auth.session
            print("[VoiceTaskParser] Auth OK — user: \(session.user.id), token expires: \(session.expiresAt)")
            
            let parseResponse: ParseResponse = try await supabase.functions.invoke(
                "parse-voice-tasks",
                options: FunctionInvokeOptions(
                    headers: ["Authorization": "Bearer \(session.accessToken)"],
                    body: requestBody
                )
            )
            
            #if DEBUG
            print("[VoiceTaskParser] Response — type: \(parseResponse.type), taskId: \(parseResponse.taskId ?? "nil"), summary: \(parseResponse.summary ?? "nil"), text: \(parseResponse.text ?? "nil"), tasks: \(parseResponse.tasks?.count ?? 0), changes: \(parseResponse.changes != nil ? "present" : "nil")")
            #endif
            
            lastAccessToken = session.accessToken
            return parseResponse
        } catch let error as FunctionsError {
            // Detailed logging for Edge Function errors
            switch error {
            case .httpError(let code, let data):
                let body = String(data: data, encoding: .utf8) ?? "(no body)"
                print("[VoiceTaskParser] HTTP \(code): \(body)")
                errorMessage = "Server error (\(code)): \(body)"
            case .relayError:
                print("[VoiceTaskParser] Relay error (Edge Function boot failure)")
                errorMessage = "Voice service temporarily unavailable"
            }
            throw error
        } catch {
            print("[VoiceTaskParser] Error: \(error)")
            errorMessage = "Failed to parse voice input: \(error.localizedDescription)"
            throw error
        }
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
