import SwiftUI

struct EmptyListView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Tasks Yet", systemImage: "checklist")
        } description: {
            Text("Tap + to create your first task")
        }
    }
}

#Preview {
    EmptyListView()
}