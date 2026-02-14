import SwiftUI

// MARK: - Growing Text Field

struct GrowingTextField: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    var placeholder: String
    
    @State private var textHeight: CGFloat = 22
    private let minHeight: CGFloat = 22
    private let maxHeight: CGFloat = 120
    
    var body: some View {
        GeometryReader { geometry in
            TextEditor(text: $text)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .font(.body)
                .frame(height: min(max(textHeight, minHeight), maxHeight))
                .onChange(of: text) { oldValue, newValue in
                    calculateHeight(for: geometry.size.width)
                }
                .onAppear {
                    calculateHeight(for: geometry.size.width)
                }
        }
        .frame(height: min(max(textHeight, minHeight), maxHeight))
    }
    
    private func calculateHeight(for width: CGFloat) {
        let size = CGSize(width: width, height: .infinity)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body)
        ]
        let boundingRect = (text as NSString).boundingRect(
            with: size,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        textHeight = max(minHeight, ceil(boundingRect.height) + 8)
    }
}

// MARK: - Plus Button

struct PlusButton: View {
    var onLongPress: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Image(systemName: "plus.circle.fill")
            .font(.system(size: 28))
            .foregroundStyle(.blue)
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
            .onLongPressGesture(minimumDuration: 0.3) {
                onLongPress()
            } onPressingChanged: { pressing in
                isPressed = pressing
            }
    }
}

// MARK: - Voice Button

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

// MARK: - Command Bar Collapsed

struct CommandBarCollapsed: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    var placeholder: String = "What do you need to get done?"
    var onVoiceTap: () -> Void
    var onSubmit: () -> Void
    var onPlusLongPress: () -> Void
    
    @State private var showingContextMenu: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Plus button with long-press
            PlusButton(onLongPress: onPlusLongPress)
            
            // Text input field
            GrowingTextField(
                text: $text,
                isFocused: $isFocused,
                placeholder: placeholder
            )
            
            // Voice/Submit button
            VoiceButton(hasText: !text.isEmpty, onTap: {
                if text.isEmpty {
                    onVoiceTap()
                } else {
                    onSubmit()
                }
            })
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .overlay(
            // Context menu overlay
            Group {
                if showingContextMenu {
                    Color.clear
                        .contextMenu {
                            Button {
                                // Manual Task action
                                showingContextMenu = false
                            } label: {
                                Label("Manual Task", systemImage: "square.and.pencil")
                            }
                            
                            Button {
                                // Attach Picture action
                                showingContextMenu = false
                            } label: {
                                Label("Attach Picture (Beta)", systemImage: "photo")
                            }
                        }
                }
            }
        )
    }
}

// MARK: - Command Bar View (Container)

struct CommandBarView: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    @Binding var showingContextMenu: Bool
    var onVoiceTap: () -> Void
    var onSubmit: () -> Void
    var placeholder: String = "What do you need to get done?"
    
    var body: some View {
        CommandBarCollapsed(
            text: $text,
            isFocused: $isFocused,
            placeholder: placeholder,
            onVoiceTap: onVoiceTap,
            onSubmit: onSubmit,
            onPlusLongPress: {
                showingContextMenu = true
            }
        )
        .frame(minHeight: 56)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Color(.systemBackground)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(
            // Context menu sheet
            Group {
                if showingContextMenu {
                    Color.black.opacity(0.001)
                        .onTapGesture {
                            showingContextMenu = false
                        }
                        .overlay(
                            VStack(spacing: 0) {
                                Button {
                                    showingContextMenu = false
                                    // Handle manual task
                                } label: {
                                    HStack {
                                        Image(systemName: "square.and.pencil")
                                        Text("Manual Task")
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color(.systemBackground))
                                }
                                .buttonStyle(.plain)
                                
                                Divider()
                                
                                Button {
                                    showingContextMenu = false
                                    // Handle attach picture
                                } label: {
                                    HStack {
                                        Image(systemName: "photo")
                                        Text("Attach Picture (Beta)")
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color(.systemBackground))
                                }
                                .buttonStyle(.plain)
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                            .frame(width: 200)
                            .position(x: 60, y: -80)
                        )
                }
            }
        )
    }
}

// MARK: - Preview

#Preview("Command Bar - Empty") {
    struct PreviewWrapper: View {
        @State private var text = ""
        @State private var isFocused = false
        @State private var showingMenu = false
        
        var body: some View {
            VStack {
                Spacer()
                CommandBarView(
                    text: $text,
                    isFocused: $isFocused,
                    showingContextMenu: $showingMenu,
                    onVoiceTap: {},
                    onSubmit: {}
                )
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    return PreviewWrapper()
}

#Preview("Command Bar - With Text") {
    struct PreviewWrapper: View {
        @State private var text = "Buy groceries for dinner tonight"
        @State private var isFocused = false
        @State private var showingMenu = false
        
        var body: some View {
            VStack {
                Spacer()
                CommandBarView(
                    text: $text,
                    isFocused: $isFocused,
                    showingContextMenu: $showingMenu,
                    onVoiceTap: {},
                    onSubmit: {}
                )
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    return PreviewWrapper()
}

#Preview("Command Bar States") {
    struct PreviewContainer: View {
        @State private var emptyText = ""
        @State private var filledText = "Buy groceries for dinner tonight"
        @State private var isFocused1 = false
        @State private var isFocused2 = false
        
        var body: some View {
            VStack(spacing: 40) {
                // Empty state
                VStack(alignment: .leading, spacing: 8) {
                    Text("Empty State")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    CommandBarCollapsed(
                        text: $emptyText,
                        isFocused: $isFocused1,
                        onVoiceTap: {},
                        onSubmit: {},
                        onPlusLongPress: {}
                    )
                }
                
                // With text state
                VStack(alignment: .leading, spacing: 8) {
                    Text("With Text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    CommandBarCollapsed(
                        text: $filledText,
                        isFocused: $isFocused2,
                        onVoiceTap: {},
                        onSubmit: {},
                        onPlusLongPress: {}
                    )
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }
    
    return PreviewContainer()
}
