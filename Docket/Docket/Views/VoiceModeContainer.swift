import SwiftUI
import SwiftData

// MARK: - Voice Mode Container

/// A container view for voice recording mode
/// Handles voice recording UI, transcription display, TTS responses,
/// and auto-restart mic after speaking
struct VoiceModeContainer: View {
    @StateObject private var speechManager = SpeechRecognitionManager()
    @StateObject private var ttsManager = TTSManager()
    @StateObject private var parser = VoiceTaskParser()
    @Binding var messages: [ConversationMessage]
    var onComplete: ([ParsedTask]) -> Void
    var onCancel: () -> Void
    
    @State private var state: VoiceRecordingState = .idle
    @State private var isProcessingUtterance = false
    @AppStorage("personalizationEnabled") private var personalizationEnabled = true
    
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncEngine.self) private var syncEngine
    @Environment(NetworkMonitor.self) private var networkMonitor
    
    /// Combines committed messages with live transcription
    private var displayMessages: [DisplayMessage] {
        var result = messages.enumerated().map { index, msg in
            DisplayMessage(id: "msg-\(index)", message: msg)
        }
        
        // Show live transcript during listening/processing
        if (state == .listening || state == .processing) && !speechManager.transcribedText.isEmpty {
            result.append(DisplayMessage(
                id: "msg-\(messages.count)",
                message: ConversationMessage(role: "user", content: speechManager.transcribedText)
            ))
        }
        
        return result
    }
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel", action: onCancel)
                        .font(.body)
                    
                    Spacer()
                    
                    Text("Voice Task")
                        .font(.headline)
                    
                    Spacer()
                    
                    // Spacer to balance cancel button
                    Text("Cancel")
                        .font(.body)
                        .opacity(0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Conversation area
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            
                            VStack(spacing: 12) {
                                // Display messages
                                ForEach(Array(displayMessages.enumerated()), id: \.element.id) { _, entry in
                                    MessageBubble(message: entry.message)
                                        .id(entry.id)
                                }
                                
                                // Processing indicator
                                if state == .processing {
                                    AIThinkingIndicator(label: "Thinking...")
                                        .padding(.vertical, 4)
                                        .id("processing")
                                }
                                
                                // TTS loading indicator
                                if state == .speaking && ttsManager.isGeneratingTTS {
                                    AIThinkingIndicator(label: "Preparing voice...")
                                        .padding(.vertical, 4)
                                        .id("tts-loading")
                                }
                                
                                // Scroll anchor
                                Color.clear
                                    .frame(height: 1)
                                    .id("bottom")
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                        .frame(minHeight: UIScreen.main.bounds.height * 0.4, alignment: .bottom)
                    }
                    .onChange(of: messages.count) { _, _ in
                        DispatchQueue.main.async {
                            scrollProxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .onChange(of: speechManager.transcribedText) { _, _ in
                        scrollProxy.scrollTo("bottom", anchor: .bottom)
                    }
                    .onChange(of: state) { _, _ in
                        scrollProxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                
                Spacer()
                
                // Mic button
                VStack(spacing: 12) {
                    Button(action: toggleRecording) {
                        ZStack {
                            // Circle background with animation
                            Circle()
                                .fill(state == .listening ? Color.red : Color.blue)
                                .frame(width: 80, height: 80)
                                .phaseAnimator([false, true], trigger: state) { content, phase in
                                    content.opacity(state == .listening && phase ? 0.8 : 1.0)
                                } animation: { _ in
                                    .easeInOut(duration: 1.2)
                                }
                            
                            // Mic icon with audio level fill
                            ZStack {
                                Image(systemName: "mic.fill")
                                    .font(.title)
                                    .foregroundStyle(.white)
                                
                                // Green level indicator
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
                    if state == .listening {
                        Text("Listening...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if state == .idle {
                        Text("Tap to start")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if state == .processing {
                        Text("Thinking...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if state == .speaking {
                        Text("Speaking...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            Task {
                let hasPermissions = await speechManager.requestPermissions()
                if !hasPermissions {
                    // Handle permission error
                    print("Microphone permissions required")
                }
                await parser.fetchVoiceProfile(isEnabled: personalizationEnabled)
            }
        }
        .onDisappear {
            speechManager.shouldResumeAfterInterruption = false
            ttsManager.stop()
            Task {
                await speechManager.stopRecording()
            }
        }
        .onChange(of: speechManager.isRecording) { oldValue, newValue in
            // Auto-process when recording stops due to silence
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
    }
    
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
        
        await speechManager.startRecording()
    }
    
    private func stopRecording() async {
        guard !isProcessingUtterance else { return }
        isProcessingUtterance = true
        state = .processing
        
        await speechManager.stopRecording()
        
        let text = speechManager.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !text.isEmpty else {
            state = .idle
            isProcessingUtterance = false
            return
        }
        
        // Commit user message
        messages.append(ConversationMessage(role: "user", content: text))
        speechManager.transcribedText = ""
        
        // Process the utterance
        await handleUserUtterance(text)
        isProcessingUtterance = false
    }
    
    private func handleUserUtterance(_ text: String) async {
        guard networkMonitor.isConnected else {
            let errorMsg = "You're offline. I'll need a connection to process that."
            messages.append(ConversationMessage(role: "assistant", content: errorMsg))
            state = .idle
            return
        }
        
        state = .processing
        
        do {
            let response = try await parser.send(messages: messages)
            
            // Handle different response types
            switch response.type {
            case "complete":
                if let tasks = response.tasks {
                    onComplete(tasks)
                    return
                }
                fallthrough
                
            default:
                // For questions or other responses, speak and continue
                let responseText = response.text ?? response.summary ?? "I'm not sure I understood. Could you try again?"
                
                messages.append(ConversationMessage(role: "assistant", content: responseText))
                
                state = .speaking
                ttsManager.speak(responseText) { [self] in
                    state = .listening
                    Task {
                        await speechManager.startRecording()
                    }
                }
            }
        } catch {
            let errorText = "Something went wrong. Want to try again?"
            messages.append(ConversationMessage(role: "assistant", content: errorText))
            state = .idle
        }
    }
}

// MARK: - Supporting Types

enum VoiceRecordingState {
    case idle
    case listening
    case processing
    case speaking
    case complete
}

struct DisplayMessage: Identifiable {
    let id: String
    let message: ConversationMessage
}

// MARK: - Preview

#Preview("Voice Mode Container") {
    struct PreviewWrapper: View {
        @State private var messages: [ConversationMessage] = []
        
        var body: some View {
            VoiceModeContainer(
                messages: $messages,
                onComplete: { tasks in
                    print("Completed with tasks: \(tasks.count)")
                },
                onCancel: {}
            )
        }
    }
    
    return PreviewWrapper()
}
