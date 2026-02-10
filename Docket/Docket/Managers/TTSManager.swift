import Foundation
import AVFoundation
import Supabase
import _Concurrency

#if DEBUG
private func voiceTraceTTS(_ event: String) {
    let t = String(format: "%.3f", Date().timeIntervalSince1970)
    print("[VoiceTrace][\(t)] \(event)")
}
#endif

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
    
    /// Reveal text and start audio in sync when possible: if TTS is ready within `boundedWait` seconds, call `onTextReveal` then play together; otherwise call `onTextReveal` then show "Preparing voice..." until playback starts. Uses 8s request timeout and Apple fallback.
    func speakWithBoundedSync(text: String, boundedWait: TimeInterval = 0.75, onTextReveal: @escaping () -> Void, onFinish: (() -> Void)?) {
        guard !isMuted else {
            onTextReveal()
            onFinish?()
            return
        }
        stop()
        completionHandler = onFinish
        if !useOpenAITTS {
            onTextReveal()
            speakWithApple(text)
            return
        }
        _Concurrency.Task {
            let fetchTask = _Concurrency.Task { await self.fetchOpenAIAudio(text: text) }
            let timeoutNs = UInt64(boundedWait * 1_000_000_000)
            _ = await withTaskGroup(of: Int.self) { group in
                group.addTask { _ = await fetchTask.value; return 1 }
                group.addTask { try? await _Concurrency.Task.sleep(nanoseconds: timeoutNs); return 2 }
                return await group.next() ?? 2
            }
            onTextReveal()
            let url = await fetchTask.value
            if let url {
                playAudioFile(url: url, fallbackText: text)
            } else {
                speakWithApple(text)
            }
        }
    }
    
    private func speakWithApple(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    
    /// Fetches OpenAI TTS audio; returns temp file URL or nil (caller should use Apple fallback). Sets isGeneratingTTS. Request timeout 8s.
    private func fetchOpenAIAudio(text: String) async -> URL? {
        struct TTSRequest: Codable {
            let text: String
            let voice: String
        }
        
        isGeneratingTTS = true
        #if DEBUG
        voiceTraceTTS("TTS start")
        #endif
        defer { isGeneratingTTS = false }
        
        do {
            let session = try await supabase.auth.session
            guard let functionURL = URL(string: "\(SupabaseConfig.urlString)/functions/v1/text-to-speech") else {
                throw NSError(domain: "TTSManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Supabase URL"])
            }
            var request = URLRequest(url: functionURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 8
            request.httpBody = try JSONEncoder().encode(TTSRequest(text: text, voice: openAITTSVoice))
            
            let (audioData, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NSError(domain: "TTSManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "TTS service returned error"])
            }
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp3")
            try audioData.write(to: tempURL)
            return tempURL
        } catch {
            print("[TTSManager] OpenAI TTS failed, falling back to Apple: \(error)")
            return nil
        }
    }
    
    private func playAudioFile(url: URL, fallbackText: String) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            audioPlayer = player
            isSpeaking = true
            #if DEBUG
            voiceTraceTTS("TTS audio ready, playback start")
            #endif
            player.play()
        } catch {
            try? FileManager.default.removeItem(at: url)
            speakWithApple(fallbackText)
        }
    }
    
    private func speakWithOpenAI(_ text: String, onFinish: (() -> Void)?) async {
        completionHandler = onFinish
        if let url = await fetchOpenAIAudio(text: text) {
            playAudioFile(url: url, fallbackText: text)
        } else {
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
            #if DEBUG
            voiceTraceTTS("TTS playback finish (Apple)")
            #endif
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
            #if DEBUG
            voiceTraceTTS("TTS playback finish (OpenAI)")
            #endif
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
