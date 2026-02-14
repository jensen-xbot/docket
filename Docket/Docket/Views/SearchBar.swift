import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search"
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 15, weight: .semibold))
            
            TextField(placeholder, text: $text)
                .font(.system(size: 16))
                .autocorrectionDisabled()
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 18))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(maxWidth: 200)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var searchText = ""
        
        var body: some View {
            VStack {
                SearchBar(text: $searchText, placeholder: "Search tasks")
                    .padding()
                
                Text("Search text: \"\(searchText)\"")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    return PreviewWrapper()
}
