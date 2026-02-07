import SwiftUI
import SwiftData

@main
struct DocketApp: App {
    @State private var authManager = AuthManager()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    TaskListView(authManager: authManager)
                        .tint(.blue)
                } else {
                    AuthView(authManager: authManager)
                }
            }
            .onOpenURL { url in
                authManager.handleAuthCallback(url: url)
            }
            .task {
                await NotificationManager.shared.requestAuthorization()
            }
        }
        .modelContainer(for: [Task.self, GroceryStore.self, IngredientLibrary.self])
    }
}

#Preview {
    TaskListView()
        .modelContainer(for: [Task.self, GroceryStore.self, IngredientLibrary.self], inMemory: true)
}
