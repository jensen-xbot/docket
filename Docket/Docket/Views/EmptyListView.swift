import SwiftUI

struct EmptyListView: View {
    let addAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Button(action: addAction) {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
            Text("No Tasks Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Tap + to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    EmptyListView(addAction: {})
}
