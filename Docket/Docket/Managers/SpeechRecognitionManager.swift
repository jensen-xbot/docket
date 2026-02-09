import Foundation
import Speech
import AVFoundation
import Combine

@Observable
@MainActor
class SpeechRecognitionManager: NSObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    var isRecording = false
    var transcribedText = ""
    var isAvailable = false
    var errorMessage: String?
    var didFinishUtterance = false // Set to true when silence timer auto-stops recording
    var audioLevel: Float = 0 // 0.0–1.0 for visual feedback
    
    private var audioSessionConfigured = false
    private var interruptionObserver: (any NSObjectProtocol)?
    private var silenceTimerTask: _Concurrency.Task<Void, Never>?
    private var levelPollTask: _Concurrency.Task<Void, Never>?
    private let silenceTimeoutSeconds: TimeInterval = 3.5 // Generous pause — users need time to think
    
    // Audio buffer for Whisper transcription
    // Using a class wrapper so we can mutate from nonisolated context
    private class AudioBufferWrapper {
        var samples: [Float] = []
        var currentLevel: Float = 0
    }
    private let audioBufferWrapper = AudioBufferWrapper()
    private var audioFormat: AVAudioFormat?
    
    override init() {
        super.init()
        checkAvailability()
        setupAudioSession()
    }
    
    private func checkAvailability() {
        guard let recognizer = speechRecognizer else {
            isAvailable = false
            errorMessage = "Speech recognition not available for this locale"
            return
        }
        isAvailable = recognizer.isAvailable
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true)
            audioSessionConfigured = true
            
            // Use block-based observer with .main queue so the handler
            // never fires on a background thread — avoids Swift 6
            // _dispatch_assert_queue_fail for @MainActor classes.
            interruptionObserver = NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: audioSession,
                queue: .main
            ) { [weak self] notification in
                guard let userInfo = notification.userInfo,
                      let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                    return
                }
                
                switch type {
                case .began:
                    // All @MainActor state access must be inside the Task
                    _Concurrency.Task { @MainActor [weak self] in
                        guard let self, self.isRecording else { return }
                        await self.stopRecording()
                    }
                case .ended:
                    break
                @unknown default:
                    break
                }
            }
        } catch {
            print("Failed to configure audio session: \(error)")
            errorMessage = "Failed to configure audio session"
        }
    }
    
    func requestPermissions() async -> Bool {
        let micStatus = AVAudioApplication.shared.recordPermission
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        
        // Request microphone permission if needed (async version avoids
        // closure-on-background-thread crash in Swift 6)
        if micStatus == .undetermined {
            _ = await AVAudioApplication.requestRecordPermission()
        }
        
        // Request speech recognition permission if needed
        if speechStatus == .notDetermined {
            await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { _ in
                    continuation.resume()
                }
            }
        }
        
        let finalMicStatus = AVAudioApplication.shared.recordPermission
        let finalSpeechStatus = SFSpeechRecognizer.authorizationStatus()
        
        let hasPermissions = finalMicStatus == .granted && finalSpeechStatus == .authorized
        
        if !hasPermissions {
            if finalMicStatus != .granted {
                errorMessage = "Microphone permission is required for voice tasks"
            } else if finalSpeechStatus != .authorized {
                errorMessage = "Speech recognition permission is required for voice tasks"
            }
        }
        
        return hasPermissions
    }
    
    func startRecording() async {
        guard !isRecording else { return }
        
        // Check permissions
        let hasPermissions = await requestPermissions()
        guard hasPermissions else {
            return
        }
        
        // Reset state
        transcribedText = ""
        errorMessage = nil
        didFinishUtterance = false
        silenceTimerTask?.cancel()
        silenceTimerTask = nil
        audioBufferWrapper.samples.removeAll()
        audioFormat = nil
        
        // Stop any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Failed to activate audio session: \(error.localizedDescription)"
            return
        }
        
        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request
        
        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        audioFormat = recordingFormat
        
        // Install tap via nonisolated helper — the closure runs on the audio
        // IO thread, so it MUST NOT be @MainActor (Swift 6 crash otherwise).
        Self.installAudioTap(
            on: inputNode,
            format: recordingFormat,
            request: request,
            audioBufferWrapper: audioBufferWrapper
        )
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isRecording = true
            startLevelPolling()
        } catch {
            errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
            recognitionRequest = nil
            return
        }
        
        // Start recognition task via nonisolated helper — the resultHandler
        // fires on a background thread, so the outer closure must not be @MainActor.
        guard let recognizer = speechRecognizer else { return }
        recognitionTask = Self.beginRecognitionTask(
            recognizer: recognizer,
            request: request,
            manager: self
        )
    }
    
    // MARK: - Nonisolated helpers
    // These are nonisolated (static) so the closures they create are NOT
    // implicitly @MainActor. Swift 6 would otherwise assume closures defined
    // inside @MainActor methods inherit @MainActor isolation and crash when
    // the audio engine / speech recognizer call them on background threads.
    
    /// Installs an audio tap whose closure runs on the audio render thread.
    private nonisolated static func installAudioTap(
        on inputNode: AVAudioInputNode,
        format: AVAudioFormat,
        request: SFSpeechAudioBufferRecognitionRequest,
        audioBufferWrapper: AudioBufferWrapper
    ) {
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
            
            // Capture audio samples for Whisper
            guard let channelData = buffer.floatChannelData else { return }
            let channelDataValue = channelData.pointee
            let frameLength = Int(buffer.frameLength)
            
            // Append samples and calculate RMS level (class property access is safe from nonisolated context)
            var sum: Float = 0
            for i in 0..<frameLength {
                audioBufferWrapper.samples.append(channelDataValue[i])
                sum += channelDataValue[i] * channelDataValue[i]
            }
            let rms = sqrt(sum / Float(max(frameLength, 1)))
            audioBufferWrapper.currentLevel = min(1.0, rms * 8)
        }
    }
    
    /// Starts recognition; the result handler fires on a background thread.
    /// Extract Sendable values (String, Bool) before hopping to @MainActor
    /// to avoid "sending non-Sendable SFSpeechRecognitionResult" errors.
    private nonisolated static func beginRecognitionTask(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        manager: SpeechRecognitionManager
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { [weak manager] result, error in
            // Extract Sendable values on this thread before crossing actor boundary
            let errorMessage: String? = {
                guard let error else { return nil }
                if (error as NSError).code == 216 { return nil } // Ignore "cancelled"
                return error.localizedDescription
            }()
            let transcription = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let hadError = error != nil
            
            _Concurrency.Task { @MainActor [weak manager] in
                guard let manager else { return }
                
                if hadError {
                    if let errorMessage {
                        manager.errorMessage = errorMessage
                    }
                    manager.isRecording = false
                    return
                }
                
                // Guard against stale callbacks: endAudio()/cancel() in
                // stopRecording() can trigger one last result delivery AFTER
                // isRecording is already false. Without this check, the
                // callback would overwrite transcribedText after the view
                // has already committed it to messages, causing the text
                // to briefly reappear as a duplicate live bubble.
                guard manager.isRecording else { return }
                
                if let transcription {
                    manager.transcribedText = transcription
                    
                    // Reset silence timer whenever new transcription arrives
                    manager.resetSilenceTimer()
                    
                    if isFinal {
                        // SFSpeechRecognizer detected end of speech
                        manager.silenceTimerTask?.cancel()
                        manager.silenceTimerTask = nil
                        await manager.stopRecording()
                    }
                }
            }
        }
    }
    
    func stopRecording() async {
        guard isRecording else { return }
        
        // Cancel silence timer and level polling
        silenceTimerTask?.cancel()
        silenceTimerTask = nil
        levelPollTask?.cancel()
        levelPollTask = nil
        audioLevel = 0
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isRecording = false
    }
    
    /// Exports the captured audio buffer as WAV format Data
    func exportAudioAsWAV() async -> Data? {
        guard !audioBufferWrapper.samples.isEmpty, let format = audioFormat else {
            return nil
        }
        
        // Convert Float samples to Int16 PCM
        let sampleRate = Int(format.sampleRate)
        let channelCount = Int(format.channelCount)
        var pcmData = Data()
        
        for sample in audioBufferWrapper.samples {
            // Clamp to [-1.0, 1.0] and convert to Int16
            let clamped = max(-1.0, min(1.0, sample))
            let int16Sample = Int16(clamped * 32767.0)
            var littleEndian = int16Sample.littleEndian
            pcmData.append(contentsOf: withUnsafeBytes(of: &littleEndian) { Data($0) })
        }
        
        // Create WAV header
        let dataSize = pcmData.count
        let fileSize = 36 + dataSize
        
        var wavData = Data()
        
        // RIFF header
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Data($0) })
        wavData.append("WAVE".data(using: .ascii)!)
        
        // fmt chunk
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) }) // fmt chunk size
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // PCM format
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(channelCount).littleEndian) { Data($0) }) // channels
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) }) // sample rate
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate * channelCount * 2).littleEndian) { Data($0) }) // byte rate
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(channelCount * 2).littleEndian) { Data($0) }) // block align
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Data($0) }) // bits per sample
        
        // data chunk
        wavData.append("data".data(using: .ascii)!)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Data($0) })
        wavData.append(pcmData)
        
        return wavData
    }
    
    /// Resets the silence detection timer. Called whenever new transcription arrives.
    /// Uses adaptive timeout: shorter for quick responses (1-2 words like "yes"),
    /// longer for ongoing dictation (3+ words).
    private func resetSilenceTimer() {
        // Cancel existing timer
        silenceTimerTask?.cancel()
        
        // Adaptive timeout based on how much the user has said:
        // - 1-2 words (e.g., "yes", "add it"): 2.5s — quick confirmation
        // - 3+ words (full sentence): 3.5s — give time to think mid-sentence
        let wordCount = transcribedText.split(separator: " ").count
        let timeout = wordCount >= 3 ? silenceTimeoutSeconds : 2.5
        
        // Start new timer
        silenceTimerTask = _Concurrency.Task { [weak self] in
            try? await _Concurrency.Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            
            guard let self else { return }
            guard !_Concurrency.Task.isCancelled else { return }
            
            // If still recording after silence timeout, auto-stop
            if self.isRecording {
                self.didFinishUtterance = true
                await self.stopRecording()
            }
        }
    }
    
    /// Polls audio level from the buffer wrapper for smooth visual feedback (~12fps)
    private func startLevelPolling() {
        levelPollTask?.cancel()
        levelPollTask = _Concurrency.Task { [weak self] in
            while !_Concurrency.Task.isCancelled {
                try? await _Concurrency.Task.sleep(nanoseconds: 80_000_000) // ~12fps
                guard let self, !_Concurrency.Task.isCancelled else { break }
                // Exponential moving average for smooth visuals
                let raw = self.audioBufferWrapper.currentLevel
                self.audioLevel = self.audioLevel * 0.3 + raw * 0.7
            }
        }
    }
    
    // deinit is nonisolated in Swift 6 and can't access @MainActor properties.
    // The observer closure captures [weak self], so when this object is
    // deallocated the closure safely becomes a no-op.
    deinit {}
}
