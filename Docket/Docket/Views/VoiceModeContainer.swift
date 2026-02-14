import SwiftUI
import SwiftData

/// Wraps voice recording into conversation format
/// Shows listening state, transcribed text, AI responses
/// Hands-free: auto-restart mic after TTS
struct VoiceModeContainer: View {
    @Binding var messages: [ConversationMessage]
    var onComplete: ([ParsedTask]) -> Void
    var onDismiss: () -> Void
    
    @StateObject private var speechManager = SpeechRecognitionManager()
    @StateObject private var ttsManager = TTSManager()
    @StateObject private var parser = VoiceTaskParser()
    
    @State private var state: VoiceRecordingState = .idle
    @State private var transcribedText = ""
    @State private var isProcessingUtterance = false
    @AppStorage("useWhisperTranscription") private var useWhisperTranscription = false
    @AppStorage("personalizationEnabled") private var personalizationEnabled = true
    
    private let conversationTimeoutSeconds: TimeInterval = 60
    @State private var conversationTimeoutTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 0) {
            // Conversation area
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        Spacer(minLength: 20)
                        
                        // Display messages
                        ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                            MessageBubble(message: message)
                                .id(index)
                        }
                        
                        // Live transcription bubble
                        if state == .listening && !speechManager.transcribedText.isEmpty {
                            MessageBubble(
                                message: ConversationMessage(
                                    role: "user",
                                    content: speechManager.transcribedText
                                )
                            )
                        }
                        
                        // Processing indicator
                        if state == .processing {
                            AIThinkingIndicator(label: "Thinking...")
                                .padding(.vertical, 4)
                        }
                        
                        // TTS generating indicator
                        if state == .speaking && ttsManager.isGeneratingTTS {
                            AIThinkingIndicator(label: "Preparing voice...")
                                .padding(.vertical, 4)
                        }
                        
                        // Bottom anchor
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal)
                }
                .onChange(of: messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: speechManager.transcribedText) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }
            
            Spacer()
            
            // Voice button at bottom
            voiceButtonArea
        }
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
        .onChange(of: speechManager.isRecording) { oldValue, newValue in
            handleRecordingStateChange(oldValue: oldValue, newValue: newValue)
        }
    }
    
    private var voiceButtonArea: some View {
        VStack(spacing: 12) {
            Button(action: toggleRecording) {
                ZStack {
                    // Animated circle background
                    Circle()
                        .fill(state == .listening ? Color.red : Color.blue)
                        .frame(width: 80, height: 80)
                        .phaseAnimator([false, true], trigger: state) { content, phase in
                            content.opacity(state == .listening && phase ? 0.8 : 1.0)
                        } animation: { _ in
                            .easeInOut(duration: 1.2)
                        }
                    
                    // Icon
                    ZStack {
                        Image(systemName: "mic.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                        
                        // Audio level indicator
                        if state == .listening {
                            Image(systemName: "mic.fill")
                                .font(.title)
                                .foregroundStyle(.green)
                                .mask(
                                    VStack(spacing: 0) {
                                        Spacer(minLength: 0)
                                        Rectangle()
                                            .frame(height: CGFloat(speechManager.audioLevel) * 30)
                                    }
                                    .frame(height: 30)
                                )
                                .animation(.easeOut(duration: 0.08), value: speechManager.audioLevel)
                        }
                    }
                }
            }
            .disabled(state == .processing || state == .speaking)
            
            // Status text
            statusText
        }
        .padding(.bottom, 32)
    }
    
    private var statusText: some View {
        Group {
            switch state {
            case .idle:
                Text("Tap to start")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .listening:
                Text("Listening...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .processing:
                Text("Processing...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .speaking:
                Text("Speaking...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .complete:
                Text("Done")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Lifecycle
    
    private func onAppear() {
        Task {
            let hasPermissions = await speechManager.requestPermissions()
            if !hasPermissions {
                // Handle permission error
            }
        }
        
        // Prefetch voice profile
        Task {
            await parser.fetchVoiceProfile(isEnabled: personalizationEnabled)
        }
        
        startConversationTimeout()
    }
    
    private func onDisappear() {
        cancelConversationTimeout()
        ttsManager.stop()
        Task {
            await speechManager.stopRecording()
        }
    }
    
    // MARK: - Recording State Handling
    
    private func handleRecordingStateChange(oldValue: Bool, newValue: Bool) {
        // Auto-process when recording stops due to silence detection
        if oldValue == true && newValue == false && state == .listening {
            let text = speechManager.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty && !isProcessingUtterance {
                Task {
                    await stopRecording()
                }
            } else if text.isEmpty {
                state = .idle
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleRecording() {
        Task {
            if state == .listening {
                await stopRecording()
            } else {
                await startRecording()
            }
        }
    }
    
    private func startRecording() async {
        state = .listening
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        
        startConversationTimeout()
        await speechManager.startRecording()
    }
    
    private func stopRecording() async {
        guard !isProcessingUtterance else { return }
        isProcessingUtterance = true
        state = .processing
        
        await speechManager.stopRecording()
        
        var text = speechManager.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle Whisper transcription if enabled
        if useWhisperTranscription, let audioData = await speechManager.exportAudioAsWAV() {
            do {
                let whisperText = try await parser.transcribe(audioData: audioData)
                if !whisperText.isEmpty {
                    text = whisperText
                }
            } catch {
                print("[VoiceModeContainer] Whisper failed, using Apple transcription: \(error)")
            }
        }
        
        guard !text.isEmpty else {
            state = .idle
            isProcessingUtterance = false
            return
        }
        
        // Commit user message
        messages.append(ConversationMessage(role: "user", content: text))
        speechManager.transcribedText = ""
        
        // Process the utterance
        await processUserUtterance(text)
        isProcessingUtterance = false
    }
    
    private func processUserUtterance(_ text: String) async {
        // Build context
        let existingTasks: [TaskContext] = [] // Would be populated from view model
        let groceryStores: [GroceryStoreContext] = [] // Would be populated from view model
        
        do {
            let response = try await parser.send(
                messages: messages,
                existingTasks: existingTasks,
                groceryStores: groceryStores,
                personalization: parser.cachedProfile
            )
            
            startConversationTimeout()
            
            switch response.type {
            case "complete":
                if let tasks = response.tasks {
                    // Add AI summary to messages
                    if let summary = response.summary {
                        await speakResponse(summary)
                    }
                    
                    // Return completed tasks
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onComplete(tasks)
                    }
                }
                
            case "question":
                if let questionText = response.text {
                    await speakResponse(questionText)
                }
                
            default:
                // Handle other response types
                if let text = response.text ?? response.summary {
                    await speakResponse(text)
                }
            }
        } catch {
            state = .idle
        }
    }
    
    private func speakResponse(_ text: String) async {
        state = .speaking
        
        messages.append(ConversationMessage(role: "assistant", content: text))
        
        ttsManager.speak(text, accessToken: parser.lastAccessToken) { [self] in
            state = .listening
            Task {
                await speechManager.startRecording()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
    
    private func startConversationTimeout() {
        conversationTimeoutTask?.cancel()
        conversationTimeoutTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(conversationTimeoutSeconds * 1_000_000_000))
            
            if state == .idle || state == .listening {
                await MainActor.run {
                    onDismiss()
                }
            }
        }
    }
    
    private func cancelConversationTimeout() {
        conversationTimeoutTask?.cancel()
        conversationTimeoutTask = nil
    }
}

// MARK: - Preview

#Preview("Voice Mode Container") {
    struct PreviewWrapper: View {
        @State private var messages: [ConversationMessage] = []
        
        var body: some View {
            VoiceModeContainer(
                messages: $messages,
                onComplete: { tasks in
                    print("Completed with \(tasks.count) tasks")
                },
                onDismiss: {
                    print("Dismissed")
                }
            )
        }
    }
    
    return PreviewWrapper()
}
