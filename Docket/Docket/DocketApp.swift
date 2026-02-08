import SwiftUI
import SwiftData
import UIKit

@main
struct DocketApp: App {
    @UIApplicationDelegateAdaptor(PushNotificationManager.self) var appDelegate
    @State private var authManager = AuthManager()
    
    init() {
        // Register for push notifications on app launch
        PushNotificationManager.shared.registerForPushNotifications()
    }
    
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
