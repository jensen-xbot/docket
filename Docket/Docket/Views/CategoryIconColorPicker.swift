import SwiftUI

struct CategoryIconColorPicker: View {
    @Binding var selectedIcon: String
    @Binding var selectedColor: String
    @Environment(\.dismiss) private var dismiss
    
    private let icons = [
        "briefcase.fill", "person.fill", "house.fill", "heart.fill",
        "dollarsign.circle.fill", "cart.fill", "bag.fill", "book.fill",
        "gamecontroller.fill", "airplane", "fork.knife", "dumbbell",
        "paintbrush.fill", "music.note", "star.fill", "flag.fill",
        "bell.fill", "gift.fill", "map.fill", "wrench.fill",
        "graduationcap.fill", "leaf.fill", "pawprint.fill", "car.fill",
        "phone.fill", "envelope.fill", "camera.fill", "lightbulb.fill",
        "globe", "trophy.fill", "tag.fill", "flame.fill"
    ]
    
    private let colors: [(name: String, hex: String, color: Color)] = [
        ("Blue", "#007AFF", .blue),
        ("Purple", "#AF52DE", .purple),
        ("Green", "#34C759", .green),
        ("Red", "#FF3B30", .red),
        ("Teal", "#5AC8FA", .teal),
        ("Orange", "#FF9500", .orange),
        ("Pink", "#FF2D55", .pink),
        ("Gray", "#8E8E93", .gray),
        ("Indigo", "#5856D6", .indigo),
        ("Yellow", "#FFCC00", .yellow)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Icon Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Icon")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                            ForEach(icons, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.title3)
                                        .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                        .frame(width: 48, height: 48)
                                        .background(selectedIcon == icon ? Color(hex: selectedColor) ?? .blue : Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Color Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                            ForEach(colors, id: \.hex) { colorItem in
                                Button {
                                    selectedColor = colorItem.hex
                                } label: {
                                    Circle()
                                        .fill(colorItem.color)
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: selectedColor == colorItem.hex ? 3 : 0)
                                        )
                                        .overlay(
                                            selectedColor == colorItem.hex ?
                                            Image(systemName: "checkmark")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.white)
                                            : nil
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Icon & Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
        }
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct CategoryIconColorPickerSheet: View {
    @Binding var categoryItem: CategoryItem
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        CategoryIconColorPicker(
            selectedIcon: Binding(
                get: { categoryItem.icon },
                set: { categoryItem.icon = $0 }
            ),
            selectedColor: Binding(
                get: { categoryItem.color },
                set: { categoryItem.color = $0 }
            )
        )
        .onDisappear {
            onSave()
        }
    }
}

#Preview {
    @Previewable @State var icon = "cart.fill"
    @Previewable @State var color = "#FF9500"
    CategoryIconColorPicker(selectedIcon: $icon, selectedColor: $color)
}
