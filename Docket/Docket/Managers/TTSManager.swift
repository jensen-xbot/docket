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

// MARK: - PCM format for gpt-4o-mini-tts streaming (24kHz, 16-bit signed LE, mono)
private let kTTSStreamSampleRate: Double = 24_000
private let kTTSStreamChunkSize = 2048 // bytes per enqueue (~42ms at 24kHz)
private let kTTSStreamPreBufferSize = 6144 // bytes to queue before starting playback (~128ms runway)

/// Manages streaming PCM playback via AVAudioEngine + AVAudioPlayerNode.
@MainActor
private final class TTSStreamingPlayer {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var onFinish: (() -> Void)?

    init() {
        format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: kTTSStreamSampleRate,
            channels: 1,
            interleaved: false
        )!
        engine.attach(playerNode)
        let mixer = engine.mainMixerNode
        engine.connect(playerNode, to: mixer, format: format)
    }

    /// Stops playback and clears completion without tearing down the engine graph.
    /// Call before play() when reusing this player for a new stream.
    func reset() {
        playerNode.stop()
        engine.stop()
        onFinish = nil
    }

    /// Prepare the engine (start it) but don't start playback yet.
    /// Call beginPlayback() after pre-buffering enough chunks.
    func prepare(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        do {
            try engine.start()
        } catch {
            onFinish()
        }
    }

    /// Start the playerNode after pre-buffer chunks have been enqueued.
    func beginPlayback() {
        playerNode.play()
    }

    func enqueueChunk(_ data: Data, isLast: Bool) {
        guard data.count >= 2 else {
            if isLast { signalComplete() }
            return
        }
        // PCM 16-bit = 2 bytes per sample; frame count = data.count / 2
        let frameCount = data.count / 2
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            if isLast { signalComplete() }
            return
        }
        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)
        data.withUnsafeBytes { raw in
            guard let src = raw.bindMemory(to: Int16.self).baseAddress else { return }
            if let dest = pcmBuffer.int16ChannelData?.pointee {
                dest.update(from: src, count: frameCount)
            }
        }
        if isLast {
            playerNode.scheduleBuffer(pcmBuffer) { [weak self] in
                DispatchQueue.main.async {
                    self?.signalComplete()
                }
            }
        } else {
            playerNode.scheduleBuffer(pcmBuffer)
        }
    }

    func signalComplete() {
        playerNode.stop()
        engine.stop()
        onFinish?()
    }

    /// Schedules a minimal silent buffer to trigger completion when stream ended on exact chunk boundary.
    func enqueueFinalCompletion() {
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1) else {
            signalComplete()
            return
        }
        buf.frameLength = 1
        if let dest = buf.int16ChannelData?.pointee {
            dest[0] = 0
        }
        playerNode.scheduleBuffer(buf) { [weak self] in
            DispatchQueue.main.async {
                self?.signalComplete()
            }
        }
    }

    func stop() {
        playerNode.stop()
        engine.stop()
        onFinish?()
    }
}

@Observable
@MainActor
class TTSManager: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var completionHandler: (() -> Void)?
    private var streamingPlayer: TTSStreamingPlayer?
    @ObservationIgnored private var streamingTask: _Concurrency.Task<Void, Never>?
    /// Reusable player instance; created once and reset between uses to avoid engine setup overhead.
    @ObservationIgnored private lazy var reusableStreamingPlayer = TTSStreamingPlayer()

    var isSpeaking = false
    var isGeneratingTTS = false

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
        if UserDefaults.standard.object(forKey: "useOpenAITTS") == nil {
            UserDefaults.standard.set(true, forKey: "useOpenAITTS")
        }
    }

    func speak(_ text: String, accessToken: String? = nil, onFinish: (() -> Void)? = nil) {
        guard !isMuted else { onFinish?(); return }
        stop()
        completionHandler = onFinish
        if useOpenAITTS {
            _Concurrency.Task { await speakWithStreaming(text, accessToken: accessToken, onFinish: onFinish) }
        } else {
            speakWithApple(text)
        }
    }

    /// Reveal text and start audio in sync when possible. Uses streaming TTS for low latency.
    /// Pass `accessToken` when available (e.g. from VoiceTaskParser.lastAccessToken) to avoid redundant auth fetch.
    func speakWithBoundedSync(text: String, boundedWait: TimeInterval = 0.75, accessToken: String? = nil, onTextReveal: @escaping () -> Void, onFinish: (() -> Void)?) {
        guard !isMuted else { onTextReveal(); onFinish?(); return }
        stop()
        completionHandler = onFinish
        if !useOpenAITTS {
            onTextReveal()
            speakWithApple(text)
            return
        }
        onTextReveal()
        let task = _Concurrency.Task {
            await speakWithStreaming(text, accessToken: accessToken, onFinish: onFinish)
        }
        streamingTask = task
    }

    private func speakWithApple(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    private func speakWithStreaming(_ text: String, accessToken: String? = nil, onFinish: (() -> Void)?) async {
        completionHandler = onFinish
        isGeneratingTTS = true
        #if DEBUG
        voiceTraceTTS("TTS streaming start")
        #endif
        defer { isGeneratingTTS = false }

        do {
            let token: String
            if let cached = accessToken {
                token = cached
            } else {
                let session = try await supabase.auth.session
                token = session.accessToken
            }
            guard let functionURL = URL(string: "\(SupabaseConfig.urlString)/functions/v1/text-to-speech") else {
                throw NSError(domain: "TTSManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Supabase URL"])
            }
            struct TTSRequest: Codable {
                let text: String
                let voice: String
                let stream: Bool
            }
            var request = URLRequest(url: functionURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30
            request.httpBody = try JSONEncoder().encode(TTSRequest(text: text, voice: openAITTSVoice, stream: true))

            // Prepare engine before HTTP request so it is ready when first bytes arrive
            let player = reusableStreamingPlayer
            player.reset()
            streamingPlayer = player
            player.prepare {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    #if DEBUG
                    voiceTraceTTS("TTS streaming playback finish")
                    #endif
                    self.isSpeaking = false
                    self.streamingPlayer = nil
                    self.reusableStreamingPlayer.reset()
                    let handler = self.completionHandler
                    self.completionHandler = nil
                    handler?()
                }
            }
            isSpeaking = true

            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NSError(domain: "TTSManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "TTS service returned error"])
            }

            // Pre-buffer: enqueue chunks before starting playback to build runway and prevent underruns
            var buffer = Data()
            var totalEnqueued = 0
            var isPlaying = false
            var didEnqueueAny = false
            for try await byte in bytes {
                buffer.append(byte)
                if buffer.count >= kTTSStreamChunkSize {
                    player.enqueueChunk(buffer, isLast: false)
                    totalEnqueued += buffer.count
                    buffer.removeAll(keepingCapacity: true)
                    didEnqueueAny = true
                    // Start playback once we have enough pre-buffered audio (~128ms runway)
                    if !isPlaying && totalEnqueued >= kTTSStreamPreBufferSize {
                        player.beginPlayback()
                        isPlaying = true
                    }
                }
            }
            // Start playback if stream ended before pre-buffer threshold (short responses)
            if !isPlaying && didEnqueueAny {
                player.beginPlayback()
                isPlaying = true
            }
            if !buffer.isEmpty {
                if !isPlaying { player.beginPlayback(); isPlaying = true }
                player.enqueueChunk(buffer, isLast: true)
            } else if !didEnqueueAny {
                // Empty stream — signal finish immediately
                player.signalComplete()
            } else {
                // Stream ended on exact chunk boundary — schedule completion via a minimal silent buffer
                player.enqueueFinalCompletion()
            }
        } catch is CancellationError {
            streamingPlayer?.stop()
            streamingPlayer = nil
            reusableStreamingPlayer.reset()
        } catch {
            print("[TTSManager] OpenAI TTS streaming failed, falling back to Apple: \(error)")
            streamingPlayer?.stop()
            streamingPlayer = nil
            reusableStreamingPlayer.reset()
            speakWithApple(text)
        }
    }

    func stop() {
        streamingTask?.cancel()
        streamingTask = nil
        streamingPlayer?.stop()
        streamingPlayer = nil
        reusableStreamingPlayer.reset()
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
        completionHandler = nil

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

    // MARK: - AVAudioPlayerDelegate (non-streaming fallback — unused in streaming path)

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let fileURL = player.url
        _Concurrency.Task { @MainActor [weak self] in
            guard let self else { return }
            isSpeaking = false
            let handler = completionHandler
            completionHandler = nil
            if let url = fileURL { try? FileManager.default.removeItem(at: url) }
            handler?()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let fileURL = player.url
        _Concurrency.Task { @MainActor [weak self] in
            guard let self else { return }
            isSpeaking = false
            completionHandler = nil
            if let url = fileURL { try? FileManager.default.removeItem(at: url) }
        }
    }
}
