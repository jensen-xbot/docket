import SwiftUI
import SwiftData
import UIKit

@main
struct DocketApp: App {
    @UIApplicationDelegateAdaptor(PushNotificationManager.self) var appDelegate
    @State private var authManager = AuthManager()
    private let modelContainer: ModelContainer
    
    init() {
        // Register for push notifications on app launch
        PushNotificationManager.shared.registerForPushNotifications()
        do {
            modelContainer = try Self.makeModelContainer()
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
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
        .modelContainer(modelContainer)
    }

    private static func makeModelContainer() throws -> ModelContainer {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let docketSupport = appSupport.appendingPathComponent("Docket", isDirectory: true)
        try FileManager.default.createDirectory(
            at: docketSupport,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let storeURL = docketSupport.appendingPathComponent("default.store")
        let config = ModelConfiguration(url: storeURL)
        return try ModelContainer(
            for: Task.self,
            GroceryStore.self,
            IngredientLibrary.self,
            configurations: config
        )
    }
}

#Preview {
    TaskListView()
        .modelContainer(for: [Task.self, GroceryStore.self, IngredientLibrary.self], inMemory: true)
}
