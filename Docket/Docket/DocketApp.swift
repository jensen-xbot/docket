import SwiftUI
import SwiftData
import UIKit

@main
struct DocketApp: App {
    @UIApplicationDelegateAdaptor(PushNotificationManager.self) var appDelegate
    @State private var authManager = AuthManager()
    @State private var networkMonitor = NetworkMonitor()
    @State private var syncEngine: SyncEngine?
    private let modelContainer: ModelContainer
    
    init() {
        // Push registration moved to AppContentView.task to avoid
        // accessing @MainActor singleton from nonisolated DocketApp.init()
        do {
            modelContainer = try DocketApp.makeModelContainer()
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
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
    
    var body: some Scene {
        WindowGroup {
            AppContentView(
                authManager: authManager,
                networkMonitor: networkMonitor,
                syncEngine: $syncEngine,
                modelContainer: modelContainer
            )
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - App Content View (handles scenePhase observation)

private struct AppContentView: View {
    let authManager: AuthManager
    let networkMonitor: NetworkMonitor
    @Binding var syncEngine: SyncEngine?
    let modelContainer: ModelContainer
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        Group {
            if authManager.isCheckingSession {
                // Splash screen while verifying saved session
                SplashView()
            } else if authManager.isAuthenticated {
                if let syncEngine = syncEngine {
                    TaskListView(authManager: authManager)
                        .tint(.blue)
                        .environment(networkMonitor)
                        .environment(syncEngine)
                } else {
                    // Show loading while SyncEngine is being created
                    ProgressView()
                        .onAppear {
                            setupSyncEngine()
                        }
                }
            } else {
                AuthView(authManager: authManager)
            }
        }
        .onOpenURL { url in
            authManager.handleAuthCallback(url: url)
        }
        .task {
            await NotificationManager.shared.requestAuthorization()
            PushNotificationManager.shared.configure()
            PushNotificationManager.shared.registerForPushNotifications()
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                setupSyncEngine()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active, authManager.isAuthenticated {
                // Sync when app comes to foreground
                _Concurrency.Task {
                    await syncEngine?.syncAll()
                }
            }
        }
        .onAppear {
            if authManager.isAuthenticated {
                setupSyncEngine()
            }
        }
    }
    
    private func setupSyncEngine() {
        guard syncEngine == nil else { return }
        
        // Create SyncEngine with NetworkMonitor
        let context = modelContainer.mainContext
        syncEngine = SyncEngine(modelContext: context, networkMonitor: networkMonitor)
        
        // Set up network reconnect callback
        networkMonitor.onReconnect = {
            _Concurrency.Task { @MainActor in
                guard let syncEngine = syncEngine else { return }
                // Flush pending queue when network reconnects
                await syncEngine.pushPendingTasks()
                await syncEngine.pushPendingGroceryStores()
                await syncEngine.pushPendingIngredients()
                // Retry failed items
                await syncEngine.retryFailedItems()
            }
        }
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
    let container = try! ModelContainer(for: Task.self, GroceryStore.self, IngredientLibrary.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    TaskListView()
        .modelContainer(container)
}
