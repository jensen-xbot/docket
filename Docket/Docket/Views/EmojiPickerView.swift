import SwiftUI

struct EmojiPickerView: View {
    let onSelect: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory = 0
    
    private let categories: [(name: String, icon: String, emojis: [String])] = [
        ("Smileys", "face.smiling", [
            "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂",
            "🙂", "😊", "😇", "🥰", "😍", "🤩", "😘", "😎",
            "🤓", "🧐", "🥳", "😏", "😌", "🤗", "🤠", "🫡",
            "😤", "🤯", "🥶", "🥵", "😈", "👻", "💀", "🤖",
        ]),
        ("People", "person.fill", [
            "👋", "🤚", "✋", "🖖", "🫱", "🫲", "👌", "🤌",
            "✌️", "🤞", "🫰", "🤟", "🤘", "🤙", "👈", "👉",
            "👆", "👇", "☝️", "👍", "👎", "✊", "👊", "🤛",
            "👏", "🙌", "🫶", "👐", "🤲", "🙏", "💪", "🦾",
        ]),
        ("Animals", "hare.fill", [
            "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼",
            "🐻‍❄️", "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵",
            "🐔", "🐧", "🐦", "🦅", "🦆", "🦉", "🐴", "🦄",
            "🐝", "🐛", "🦋", "🐌", "🐙", "🦑", "🐠", "🐬",
        ]),
        ("Nature", "leaf.fill", [
            "🌸", "🌺", "🌻", "🌼", "🌷", "🌹", "🥀", "💐",
            "🌲", "🌳", "🌴", "🍁", "🍂", "🍃", "🍀", "🌵",
            "🌾", "🌿", "☘️", "🪴", "🍄", "🌰", "🪨", "🌊",
            "🔥", "❄️", "⛄️", "🌈", "☀️", "🌙", "⭐️", "✨",
        ]),
        ("Food", "fork.knife", [
            "🍎", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐",
            "🍑", "🥝", "🥑", "🍔", "🌮", "🌯", "🍕", "🍣",
            "🍩", "🍪", "🎂", "🍰", "🧁", "🍫", "🍿", "☕️",
            "🍺", "🍷", "🥂", "🧃", "🧋", "🥤", "🍵", "🥛",
        ]),
        ("Activities", "sportscourt.fill", [
            "⚽️", "🏀", "🏈", "⚾️", "🥎", "🎾", "🏐", "🏓",
            "🎯", "🏆", "🥇", "🎮", "🕹️", "🎲", "🎨", "🎸",
            "🎹", "🎺", "🥁", "🎭", "🏋️", "🚴", "🏄", "🧗",
            "🎪", "🎠", "🎡", "🎢", "🏕️", "⛺️", "🗺️", "🧭",
        ]),
        ("Hearts", "heart.fill", [
            "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍",
            "🤎", "💔", "❤️‍🔥", "❤️‍🩹", "💕", "💞", "💓", "💗",
            "💖", "💘", "💝", "💟", "♥️", "🫀", "💋", "💌",
            "💎", "👑", "🎀", "🏅", "🔮", "🪬", "🧿", "⚡️",
        ]),
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(categories.enumerated()), id: \.offset) { index, category in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCategory = index
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: category.icon)
                                        .font(.title3)
                                    Text(category.name)
                                        .font(.caption2)
                                }
                                .foregroundStyle(selectedCategory == index ? .blue : .secondary)
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .background(.ultraThinMaterial)
                
                Divider()
                
                // Emoji grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 12) {
                        ForEach(categories[selectedCategory].emojis, id: \.self) { emoji in
                            Button {
                                onSelect(emoji)
                                dismiss()
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 32))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Choose Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    EmojiPickerView { emoji in
        print("Selected: \(emoji)")
    }
}
