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
                if authManager.isCheckingSession {
                    // Splash screen while verifying saved session
                    SplashView()
                } else if authManager.isAuthenticated {
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

// MARK: - Splash Screen

private struct SplashView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    
    var body: some View {
        VStack(spacing: 20) {
            Image("DocketLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
            
            Text("Docket")
                .font(.system(size: 32, weight: .bold))
                .opacity(logoOpacity)
            
            ProgressView()
                .controlSize(.regular)
                .padding(.top, 8)
                .opacity(logoOpacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
    }
}

#Preview {
    TaskListView()
        .modelContainer(for: [Task.self, GroceryStore.self, IngredientLibrary.self], inMemory: true)
}
