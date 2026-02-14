import SwiftUI

struct EmptyListView: View {
    let addAction: () -> Void
    var showCommandBarCTA: Bool = true

    var body: some View {
        VStack(spacing: 16) {
            if !showCommandBarCTA {
                // Legacy button (for backward compatibility)
                Button(action: addAction) {
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
            }
            Text("No Tasks Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text(showCommandBarCTA ? "Tap below to create your first task" : "Tap + to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    EmptyListView(addAction: {})
}
