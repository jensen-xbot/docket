import SwiftUI

// MARK: - Plus Button

/// A button with a plus icon that supports long-press to show context menu
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

// MARK: - Preview

#Preview("Plus Button") {
    HStack(spacing: 40) {
        PlusButton(onLongPress: {
            print("Long pressed!")
        })
        
        PlusButton(onLongPress: {})
            .environment(\.colorScheme, .dark)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
