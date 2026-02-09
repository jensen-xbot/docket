import Foundation
import AVFoundation
import Supabase
import _Concurrency

@Observable
@MainActor
class TTSManager: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var completionHandler: (() -> Void)?
    
    var isSpeaking = false
    var isGeneratingTTS = false // True while fetching/generating OpenAI TTS audio
    
    // Preferences
    private var isMuted: Bool {
        UserDefaults.standard.bool(forKey: "ttsMuted")
    }
    
    private var useOpenAITTS: Bool {
        UserDefaults.standard.bool(forKey: "useOpenAITTS")
    }
    
    private var openAITTSVoice: String {
        UserDefaults.standard.string(forKey: "openAITTSVoice") ?? "nova"
    }
    
    private let supabase = SupabaseConfig.client
    
    override init() {
        super.init()
        synthesizer.delegate = self
        
        // Set default preference if not set (default to OpenAI TTS)
        if UserDefaults.standard.object(forKey: "useOpenAITTS") == nil {
            UserDefaults.standard.set(true, forKey: "useOpenAITTS")
        }
    }
    
    func speak(_ text: String, onFinish: (() -> Void)? = nil) {
        // Don't speak if muted
        guard !isMuted else {
            onFinish?()
            return
        }
        
        // Stop any current speech
        stop()
        
        completionHandler = onFinish
        
        // Route to OpenAI or Apple based on preference
        if useOpenAITTS {
            _Concurrency.Task {
                await speakWithOpenAI(text, onFinish: onFinish)
            }
        } else {
            speakWithApple(text)
        }
    }
    
    private func speakWithApple(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    
    private func speakWithOpenAI(_ text: String, onFinish: (() -> Void)?) async {
        struct TTSRequest: Codable {
            let text: String
            let voice: String
        }
        
        // Set generating flag immediately so UI can show loading state
        isGeneratingTTS = true
        
        do {
            // Get auth session and build Edge Function URL
            let session = try await supabase.auth.session
            guard let functionURL = URL(string: "\(SupabaseConfig.urlString)/functions/v1/text-to-speech") else {
                throw NSError(domain: "TTSManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Supabase URL"])
            }
            
            // Build request
            var request = URLRequest(url: functionURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let requestBody = TTSRequest(text: text, voice: openAITTSVoice)
            request.httpBody = try JSONEncoder().encode(requestBody)
            
            // Call Edge Function and get binary MP3 data
            let (audioData, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NSError(domain: "TTSManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "TTS service returned error"])
            }
            
            // Write to temp file (AVAudioPlayer needs a file URL)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp3")
            
            try audioData.write(to: tempURL)
            
            // Create and play audio player
            let player = try AVAudioPlayer(contentsOf: tempURL)
            player.delegate = self
            audioPlayer = player
            
            // Clear generating flag and start playing
            isGeneratingTTS = false
            isSpeaking = true
            player.play()
            
        } catch {
            print("[TTSManager] OpenAI TTS failed, falling back to Apple: \(error)")
            isGeneratingTTS = false
            // Fallback to Apple TTS on error
            speakWithApple(text)
        }
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
        completionHandler = nil
        
        // Clean up temp files
        let tempDir = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "mp3" {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
    
    // MARK: - AVSpeechSynthesizerDelegate (Apple TTS)
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        _Concurrency.Task { @MainActor in
            isSpeaking = false
            let handler = completionHandler
            completionHandler = nil
            handler?()
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        _Concurrency.Task { @MainActor in
            isSpeaking = false
            completionHandler = nil
        }
    }
    
    // MARK: - AVAudioPlayerDelegate (OpenAI TTS)
    
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Extract Sendable value before crossing actor boundary
        let fileURL = player.url
        
        _Concurrency.Task { @MainActor [weak self] in
            guard let self else { return }
            self.isSpeaking = false
            let handler = self.completionHandler
            self.completionHandler = nil
            
            // Clean up temp file
            if let url = fileURL {
                try? FileManager.default.removeItem(at: url)
            }
            
            handler?()
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        // Extract Sendable value before crossing actor boundary
        let fileURL = player.url
        
        _Concurrency.Task { @MainActor [weak self] in
            guard let self else { return }
            self.isSpeaking = false
            self.completionHandler = nil
            
            // Clean up temp file
            if let url = fileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
