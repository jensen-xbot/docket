import SwiftUI
import SwiftData
import _Concurrency

/// Voice mode integration for CommandBar
/// Wraps VoiceRecordingView logic for use within CommandBar context
struct CommandBarVoiceMode: View {
    @Binding var isActive: Bool
    @Binding var messages: [ConversationMessage]
    var onTranscriptionComplete: (String) -> Void
    var onClose: () -> Void
    
    @State private var speechManager = SpeechRecognitionManager()
    @State private var ttsManager = TTSManager()
    @State private var parser = VoiceTaskParser()
    @State private var state: VoiceModeState = .idle
    @State private var errorMessage: String?
    @State private var audioLevel: CGFloat = 0
    
    @Environment(SyncEngine.self) private var syncEngine
    
    enum VoiceModeState {
        case idle
        case listening
        case processing
        case speaking
    }
    
    var body: some View {
        ZStack {
            // Voice UI
            VStack(spacing: 20) {
                // Status text
                Text(statusText)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .animation(.easeInOut(duration: 0.3), value: state)
                
                // Audio waveform visualization
                audioWaveform
                
                // Live transcription
                if !speechManager.transcribedText.isEmpty {
                    Text(speechManager.transcribedText)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }
                
                // Controls
                HStack(spacing: 32) {
                    // Cancel button
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                    }
                    
                    // Mic button (main action)
                    micButton
                    
                    // Done button (when has transcription)
                    if !speechManager.transcribedText.isEmpty {
                        Button(action: commitTranscription) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
            )
            .padding(.horizontal, 32)
        }
        .onAppear(perform: onAppear)
        .onChange(of: state) { _, newState in
            handleStateChange(newState)
        }
    }
    
    // MARK: - Components
    
    private var statusText: String {
        switch state {
        case .idle: return "Tap to speak"
        case .listening: return "Listening..."
        case .processing: return "Processing..."
        case .speaking: return "Speaking..."
        }
    }
    
    private var audioWaveform: some View {
        GeometryReader { geometry in
            HStack(spacing: 4) {
                ForEach(0..<20, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue.opacity(0.6 + Double(index % 3) * 0.15))
                        .frame(width: 4)
                        .frame(height: barHeight(for: index, in: geometry))
                        .animation(.easeInOut(duration: 0.1).delay(Double(index) * 0.02), value: audioLevel)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
        }
        .frame(height: 60)
        .onAppear {
            startAudioLevelUpdates()
        }
    }
    
    private func barHeight(for index: Int, in geometry: GeometryProxy) -> CGFloat {
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = geometry.size.height
        let level = state == .listening ? audioLevel : 0.3
        let randomFactor = sin(Double(index) * 0.5 + Date().timeIntervalSince1970 * 10) * 0.5 + 0.5
        return baseHeight + (maxHeight - baseHeight) * CGFloat(level) * CGFloat(randomFactor)
    }
    
    private var micButton: some View {
        Button(action: handleMicTap) {
            ZStack {
                Circle()
                    .fill(state == .listening ? Color.red : Color.blue)
                    .frame(width: 72, height: 72)
                
                Image(systemName: state == .listening ? "stop.fill" : "mic.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }
        }
        .disabled(state == .processing || state == .speaking)
    }
    
    // MARK: - Actions
    
    private func handleMicTap() {
        switch state {
        case .idle:
            startListening()
        case .listening:
            stopListening()
        case .processing, .speaking:
            break // Disabled
        }
    }
    
    private func startListening() {
        state = .listening
        Task {
            await speechManager.startRecording()
        }
    }
    
    private func stopListening() {
        state = .processing
        Task {
            let transcription = await speechManager.stopRecording()
            processTranscription(transcription)
        }
    }
    
    private func processTranscription(_ text: String) {
        guard !text.isEmpty else {
            state = .idle
            return
        }
        
        onTranscriptionComplete(text)
        state = .idle
    }
    
    private func commitTranscription() {
        let text = speechManager.transcribedText
        speechManager.clearTranscription()
        onTranscriptionComplete(text)
    }
    
    private func onAppear() {
        // Greeting TTS
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            // TTS greeting would go here
        }
    }
    
    private func handleStateChange(_ newState: VoiceModeState) {
        // Handle audio session changes
    }
    
    private func startAudioLevelUpdates() {
        // Simulate audio level for visualization
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if state == .listening {
                audioLevel = CGFloat.random(in: 0.3...1.0)
            } else {
                audioLevel = 0.3
            }
        }
    }
}

// MARK: - Preview

#Preview("Command Bar Voice Mode") {
    struct PreviewWrapper: View {
        @State var isActive = true
        @State var messages: [ConversationMessage] = []
        
        var body: some View {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                CommandBarVoiceMode(
                    isActive: $isActive,
                    messages: $messages,
                    onTranscriptionComplete: { text in
                        print("Transcribed: \(text)")
                    },
                    onClose: {}
                )
            }
        }
    }
    
    return PreviewWrapper()
}
