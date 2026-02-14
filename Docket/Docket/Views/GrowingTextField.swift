import SwiftUI

// MARK: - Growing Text Field

/// An auto-expanding text field that grows vertically like iMessage
/// Supports multi-line input with a minimum and maximum height
struct GrowingTextField: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    var placeholder: String = "What do you need to get done?"
    
    @State private var textHeight: CGFloat = 22
    private let minHeight: CGFloat = 22
    private let maxHeight: CGFloat = 120
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Placeholder text
                if text.isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                        .transition(.opacity)
                }
                
                // Text editor
                TextEditor(text: $text)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .font(.body)
                    .frame(height: min(max(textHeight, minHeight), maxHeight))
            }
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

// MARK: - Preview

#Preview("Growing Text Field") {
    struct PreviewContainer: View {
        @State private var shortText = ""
        @State private var mediumText = "This is a medium length task description"
        @State private var longText = "This is a very long task description that should wrap to multiple lines and demonstrate the growing behavior of the text field like iMessage style input"
        @State private var isFocused = false
        
        var body: some View {
            VStack(spacing: 24) {
                // Empty state
                VStack(alignment: .leading, spacing: 8) {
                    Text("Empty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    GrowingTextField(text: $shortText, isFocused: $isFocused)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                // Medium text
                VStack(alignment: .leading, spacing: 8) {
                    Text("Medium Text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    GrowingTextField(text: $mediumText, isFocused: $isFocused)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                // Long text (multi-line)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Long Text (Multi-line)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    GrowingTextField(text: $longText, isFocused: $isFocused)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }
    
    return PreviewContainer()
}
