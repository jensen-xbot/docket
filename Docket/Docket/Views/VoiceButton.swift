import SwiftUI

// MARK: - Voice Button

/// A button that morphs between voice waveform and submit arrow
/// Shows 5-bar waveform icon when no text, submit arrow when text is present
struct VoiceButton: View {
    var hasText: Bool
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // 5 bars icon (shown when empty)
                Image(systemName: "waveform")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(hasText ? .clear : .blue)
                    .opacity(hasText ? 0 : 1)
                
                // Submit arrow (shown when has text)
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(hasText ? .blue : .clear)
                    .opacity(hasText ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: hasText)
    }
}

// MARK: - Preview

#Preview("Voice Button States") {
    struct PreviewContainer: View {
        @State private var hasText = false
        
        var body: some View {
            VStack(spacing: 40) {
                // Empty state
                VStack(spacing: 8) {
                    Text("Empty (Voice)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    VoiceButton(hasText: false, onTap: {})
                }
                
                // With text state
                VStack(spacing: 8) {
                    Text("With Text (Submit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    VoiceButton(hasText: true, onTap: {})
                }
                
                // Interactive toggle
                VStack(spacing: 8) {
                    Text("Tap to Toggle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    VoiceButton(hasText: hasText, onTap: {
                        withAnimation {
                            hasText.toggle()
                        }
                    })
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }
    
    return PreviewContainer()
}
