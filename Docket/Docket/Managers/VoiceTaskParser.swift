import Foundation
import Supabase
import _Concurrency

struct ParseRequest: Codable {
    let messages: [ConversationMessage]
    let today: String
    let timezone: String
    let contacts: [String]?
    let existingTasks: [TaskContext]?
    let groceryStores: [GroceryStoreContext]?
}

@Observable
@MainActor
class VoiceTaskParser {
    private let supabase = SupabaseConfig.client
    
    var isProcessing = false
    var errorMessage: String?
    
    func send(messages: [ConversationMessage], existingTasks: [TaskContext]? = nil, groceryStores: [GroceryStoreContext]? = nil) async throws -> ParseResponse {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        
        // Format today's date as yyyy-MM-dd
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let timezone = TimeZone.current.identifier
        
        // Build request body
        let requestBody = ParseRequest(
            messages: messages,
            today: String(today),
            timezone: timezone,
            contacts: nil,
            existingTasks: existingTasks,
            groceryStores: groceryStores
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
}
