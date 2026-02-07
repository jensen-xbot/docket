import SwiftUI
import SwiftData

@main
struct DocketApp: App {
    var body: some Scene {
        WindowGroup {
            TaskListView()
                .tint(.blue)
        }
        .modelContainer(for: Task.self)
    }
}

#Preview {
    TaskListView()
        .modelContainer(for: Task.self, inMemory: true)
}
