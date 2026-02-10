import Foundation
import Supabase
import SwiftData
import _Concurrency

@MainActor
@Observable
class SyncEngine {
    private let supabase = SupabaseConfig.client
    private let modelContext: ModelContext
    private let networkMonitor: NetworkMonitor?
    
    var isSyncing = false
    var lastSyncDate: Date?
    var syncError: String?
    var sharerProfiles: [String: UserProfile] = [:]
    /// Per-task recipient profiles for owner-side "shared with" visibility (taskId -> [UserProfile]).
    var sharedWithProfiles: [UUID: [UserProfile]] = [:]
    private var didSubscribe = false
    
    init(modelContext: ModelContext, networkMonitor: NetworkMonitor? = nil) {
        self.modelContext = modelContext
        self.networkMonitor = networkMonitor
    }
    
    // Check if network is available before sync operations
    private var isNetworkAvailable: Bool {
        networkMonitor?.isConnected ?? true // Default to true if no monitor
    }
    
    // Pull remote tasks and merge with local
    func pullTasks() async {
        guard isNetworkAvailable else {
            print("Skipping pullTasks: network unavailable")
            return
        }
        
        isSyncing = true
        syncError = nil
        defer { isSyncing = false }
        
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id.uuidString
            
            let ownedResponse: [TaskDTO] = try await supabase
                .from("tasks")
                .select()
                .eq("user_id", value: userId)
                .order("updated_at", ascending: false)
                .execute()
                .value
            
            let sharedIds: [UUID]
            do {
                let shares: [TaskShareRow] = try await supabase
                    .from("task_shares")
                    .select()
                    .eq("shared_with_id", value: userId)
                    .eq("status", value: "accepted")
                    .execute()
                    .value
                sharedIds = shares.map { $0.taskId }
            } catch {
                sharedIds = []
            }
            
            let sharedResponse: [TaskDTO]
            if sharedIds.isEmpty {
                sharedResponse = []
            } else {
                do {
                    sharedResponse = try await supabase
                        .from("tasks")
                        .select()
                        .in("id", values: sharedIds.map { $0.uuidString })
                        .execute()
                        .value
                } catch {
                    sharedResponse = []
                }
            }
            
            let descriptor = FetchDescriptor<Task>()
            let localTasks = try? modelContext.fetch(descriptor)
            
            for dto in ownedResponse {
                if let existing = localTasks?.first(where: { $0.id == dto.id }) {
                    if dto.updatedAt > existing.updatedAt {
                        // Conflict detection: if local has pending changes, log a warning
                        if existing.syncStatus == SyncStatus.pending.rawValue {
                            print("⚠️ Conflict detected: Local pending changes for task '\(existing.title)' overwritten by remote (remote updatedAt: \(dto.updatedAt), local updatedAt: \(existing.updatedAt))")
                        }
                        existing.title = dto.title
                        existing.isCompleted = dto.isCompleted
                        existing.dueDate = dto.dueDate
                        existing.hasTime = dto.hasTime
                        existing.priority = dto.toTask().priority
                        existing.category = dto.category
                        existing.notes = dto.notes
                        existing.completedAt = dto.completedAt
                        existing.isPinned = dto.isPinned
                        existing.sortOrder = dto.sortOrder
                        existing.checklistItems = dto.checklistItems
                        existing.progressPercentage = dto.progressPercentage
                        existing.isProgressEnabled = dto.isProgressEnabled
                        existing.lastProgressUpdate = dto.lastProgressUpdate
                        existing.isShared = false
                        existing.updatedAt = dto.updatedAt
                        existing.syncStatus = SyncStatus.synced.rawValue
                    } else {
                        // Local is newer or same, but ensure sync status is correct
                        if existing.syncStatus == SyncStatus.synced.rawValue {
                            // Already synced, no action needed
                        }
                    }
                } else {
                    let task = dto.toTask()
                    task.userId = userId
                    task.isShared = false
                    modelContext.insert(task)
                }
            }
            
            for dto in sharedResponse {
                if let existing = localTasks?.first(where: { $0.id == dto.id }) {
                    if dto.updatedAt > existing.updatedAt {
                        // Conflict detection: if local has pending changes, log a warning
                        if existing.syncStatus == SyncStatus.pending.rawValue {
                            print("⚠️ Conflict detected: Local pending changes for shared task '\(existing.title)' overwritten by remote (remote updatedAt: \(dto.updatedAt), local updatedAt: \(existing.updatedAt))")
                        }
                        existing.title = dto.title
                        existing.isCompleted = dto.isCompleted
                        existing.dueDate = dto.dueDate
                        existing.hasTime = dto.hasTime
                        existing.priority = dto.toTask().priority
                        existing.category = dto.category
                        existing.notes = dto.notes
                        existing.completedAt = dto.completedAt
                        existing.isPinned = dto.isPinned
                        existing.sortOrder = dto.sortOrder
                        existing.checklistItems = dto.checklistItems
                        existing.progressPercentage = dto.progressPercentage
                        existing.isProgressEnabled = dto.isProgressEnabled
                        existing.lastProgressUpdate = dto.lastProgressUpdate
                        existing.isShared = true
                        existing.updatedAt = dto.updatedAt
                        existing.syncStatus = SyncStatus.synced.rawValue
                    } else {
                        existing.isShared = true
                    }
                } else {
                    let task = dto.toTask()
                    task.userId = dto.userId
                    task.isShared = true
                    modelContext.insert(task)
                }
            }
            
            try? modelContext.save()
            
            // Fetch sharer profiles for shared tasks
            await fetchSharerProfiles(userId: userId)
            // Fetch recipient profiles for owner-side "shared with" visibility
            await fetchSharedWithProfiles(userId: userId)
            
            lastSyncDate = Date()
        } catch {
            syncError = error.localizedDescription
            print("Pull error: \(error)")
        }
    }
    
    // Fetch profiles of users who shared tasks with current user
    private func fetchSharerProfiles(userId: String) async {
        do {
            // Get unique owner IDs from shared tasks
            let shares: [TaskShareRow] = try await supabase
                .from("task_shares")
                .select("owner_id, task_id")
                .eq("shared_with_id", value: userId)
                .eq("status", value: "accepted")
                .execute()
                .value
            
            let ownerIds = Array(Set(shares.map { $0.ownerId })) // Get unique owner IDs
            
            if ownerIds.isEmpty {
                return
            }
            
            // Fetch profiles for these owners
            let profiles: [UserProfile] = try await supabase
                .from("user_profiles")
                .select()
                .in("id", values: ownerIds.map { $0.uuidString })
                .execute()
                .value
            
            // Cache profiles by user ID
            for profile in profiles {
                sharerProfiles[profile.id.uuidString] = profile
            }
        } catch {
            print("Error fetching sharer profiles: \(error)")
        }
    }
    
    // Fetch recipient profiles for tasks the current user owns and has shared
    private func fetchSharedWithProfiles(userId: String) async {
        do {
            struct OwnerShareRow: Codable {
                let taskId: UUID
                let sharedWithId: UUID?
                enum CodingKeys: String, CodingKey {
                    case taskId = "task_id"
                    case sharedWithId = "shared_with_id"
                }
            }
            let shares: [OwnerShareRow] = try await supabase
                .from("task_shares")
                .select("task_id, shared_with_id")
                .eq("owner_id", value: userId)
                .eq("status", value: "accepted")
                .execute()
                .value
            
            let recipientIds = shares.compactMap { $0.sharedWithId }.map { $0.uuidString }
            guard !recipientIds.isEmpty else {
                sharedWithProfiles = [:]
                return
            }
            
            let profiles: [UserProfile] = try await supabase
                .from("user_profiles")
                .select()
                .in("id", values: recipientIds)
                .execute()
                .value
            
            let profileById: [String: UserProfile] = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id.uuidString, $0) })
            var result: [UUID: [UserProfile]] = [:]
            for share in shares {
                guard let sid = share.sharedWithId else { continue }
                let idStr = sid.uuidString
                if let profile = profileById[idStr] {
                    // Deduplicate: skip if this recipient is already in the list for this task
                    if !result[share.taskId, default: []].contains(where: { $0.id == profile.id }) {
                        result[share.taskId, default: []].append(profile)
                    }
                }
            }
            sharedWithProfiles = result
        } catch {
            print("Error fetching shared-with profiles: \(error)")
        }
    }
    
    // Push a single task to Supabase
    func pushTask(_ task: Task) async {
        guard isNetworkAvailable else {
            // If offline, leave as pending (don't mark as failed)
            task.syncStatus = SyncStatus.pending.rawValue
            try? modelContext.save()
            return
        }
        
        do {
            let session = try await supabase.auth.session
            let currentUserId = session.user.id.uuidString
            
            task.updatedAt = Date()
            
            // Shared tasks (owned by someone else) already exist remotely —
            // use UPDATE so we go through the "Recipients can update" RLS policy
            // instead of INSERT, which requires auth.uid() = user_id.
            if task.isShared, let ownerId = task.userId, ownerId != currentUserId {
                let dto = TaskDTO(from: task, userId: ownerId)
                try await supabase
                    .from("tasks")
                    .update(dto)
                    .eq("id", value: task.id.uuidString)
                    .execute()
            } else {
                let dto = TaskDTO(from: task, userId: currentUserId)
                try await supabase
                    .from("tasks")
                    .upsert(dto, onConflict: "id")
                    .execute()
            }
            
            task.syncStatus = SyncStatus.synced.rawValue
            try? modelContext.save()
        } catch {
            task.syncStatus = SyncStatus.failed.rawValue
            try? modelContext.save()
            print("Push error: \(error)")
        }
    }
    
    // Push all pending tasks
    func pushPendingTasks() async {
        isSyncing = true
        defer { isSyncing = false }
        
        let syncedValue = 0
        let descriptor = FetchDescriptor<Task>(
            predicate: #Predicate<Task> { task in
                task.syncStatus != syncedValue
            }
        )
        
        let pendingTasks = (try? modelContext.fetch(descriptor)) ?? []
        
        for task in pendingTasks {
            await pushTask(task)
        }
    }
    
    // Delete task from Supabase (call BEFORE deleting from SwiftData)
    func deleteRemoteTask(id: UUID, syncStatus: Int) async {
        if syncStatus == SyncStatus.pending.rawValue {
            return
        }
        
        do {
            try await supabase
                .from("tasks")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
        } catch {
            print("Remote delete error: \(error)")
        }
    }
    
    // Pull remote grocery stores and merge with local
    func pullGroceryStores() async {
        guard isNetworkAvailable else {
            print("Skipping pullGroceryStores: network unavailable")
            return
        }
        
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id.uuidString
            
            let remoteStores: [GroceryStoreDTO] = try await supabase
                .from("grocery_stores")
                .select()
                .eq("user_id", value: userId)
                .order("updated_at", ascending: false)
                .execute()
                .value
            
            let descriptor = FetchDescriptor<GroceryStore>()
            let localStores = try? modelContext.fetch(descriptor)
            
            for dto in remoteStores {
                if let existing = localStores?.first(where: { $0.id == dto.id }) {
                    if dto.updatedAt > existing.updatedAt {
                        existing.userId = userId
                        existing.name = dto.name
                        existing.items = dto.items
                        existing.updatedAt = dto.updatedAt
                        existing.syncStatus = SyncStatus.synced.rawValue
                    }
                } else {
                    let store = dto.toGroceryStore()
                    modelContext.insert(store)
                }
            }
            
            try? modelContext.save()
        } catch {
            print("Grocery pull error: \(error)")
        }
    }
    
    // Push a single grocery store to Supabase
    func pushGroceryStore(_ store: GroceryStore) async {
        guard isNetworkAvailable else {
            // If offline, leave as pending (don't mark as failed)
            store.syncStatus = SyncStatus.pending.rawValue
            try? modelContext.save()
            return
        }
        
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id.uuidString
            
            store.userId = userId
            store.updatedAt = Date()
            let dto = GroceryStoreDTO(from: store, userId: userId)
            
            try await supabase
                .from("grocery_stores")
                .upsert(dto, onConflict: "id")
                .execute()
            
            store.syncStatus = SyncStatus.synced.rawValue
            try? modelContext.save()
        } catch {
            store.syncStatus = SyncStatus.failed.rawValue
            try? modelContext.save()
            print("Grocery push error: \(error)")
        }
    }
    
    // Push all pending grocery stores
    func pushPendingGroceryStores() async {
        let syncedValue = 0
        let descriptor = FetchDescriptor<GroceryStore>(
            predicate: #Predicate<GroceryStore> { store in
                store.syncStatus != syncedValue
            }
        )
        
        let pendingStores = (try? modelContext.fetch(descriptor)) ?? []
        
        for store in pendingStores {
            await pushGroceryStore(store)
        }
    }
    
    // Delete grocery store from Supabase (call BEFORE deleting from SwiftData)
    func deleteRemoteGroceryStore(id: UUID, syncStatus: Int) async {
        if syncStatus == SyncStatus.pending.rawValue {
            return
        }
        
        do {
            try await supabase
                .from("grocery_stores")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
        } catch {
            print("Remote grocery delete error: \(error)")
        }
    }
    
    // Pull remote ingredients and merge with local
    func pullIngredients() async {
        guard isNetworkAvailable else {
            print("Skipping pullIngredients: network unavailable")
            return
        }
        
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id.uuidString
            
            let remoteIngredients: [IngredientLibraryDTO] = try await supabase
                .from("ingredients")
                .select()
                .eq("user_id", value: userId)
                .order("updated_at", ascending: false)
                .execute()
                .value
            
            let descriptor = FetchDescriptor<IngredientLibrary>()
            let localIngredients = try? modelContext.fetch(descriptor)
            
            for dto in remoteIngredients {
                if let existing = localIngredients?.first(where: { $0.id == dto.id }) {
                    if dto.updatedAt > existing.updatedAt {
                        existing.userId = userId
                        existing.name = dto.name
                        existing.displayName = dto.displayName
                        existing.useCount = dto.useCount
                        existing.updatedAt = dto.updatedAt
                        existing.syncStatus = SyncStatus.synced.rawValue
                    }
                } else {
                    let ingredient = dto.toIngredientLibrary()
                    modelContext.insert(ingredient)
                }
            }
            
            try? modelContext.save()
        } catch {
            print("Ingredient pull error: \(error)")
        }
    }
    
    // Push a single ingredient to Supabase
    func pushIngredient(_ ingredient: IngredientLibrary) async {
        guard isNetworkAvailable else {
            // If offline, leave as pending (don't mark as failed)
            ingredient.syncStatus = SyncStatus.pending.rawValue
            try? modelContext.save()
            return
        }
        
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id.uuidString
            
            ingredient.userId = userId
            ingredient.updatedAt = Date()
            let dto = IngredientLibraryDTO(from: ingredient, userId: userId)
            
            try await supabase
                .from("ingredients")
                .upsert(dto, onConflict: "id")
                .execute()
            
            ingredient.syncStatus = SyncStatus.synced.rawValue
            try? modelContext.save()
        } catch {
            ingredient.syncStatus = SyncStatus.failed.rawValue
            try? modelContext.save()
            print("Ingredient push error: \(error)")
        }
    }
    
    // Push all pending ingredients
    func pushPendingIngredients() async {
        let syncedValue = 0
        let descriptor = FetchDescriptor<IngredientLibrary>(
            predicate: #Predicate<IngredientLibrary> { ingredient in
                ingredient.syncStatus != syncedValue
            }
        )
        
        let pendingIngredients = (try? modelContext.fetch(descriptor)) ?? []
        
        for ingredient in pendingIngredients {
            await pushIngredient(ingredient)
        }
    }
    
    // Full sync: pull then push
    func syncAll() async {
        await pullTasks()
        await pushPendingTasks()
        await pullGroceryStores()
        await pushPendingGroceryStores()
        await pullIngredients()
        await pushPendingIngredients()
        await subscribeToSharedTasks()
    }
    
    private var tasksChannel: RealtimeChannelV2?
    private var taskSharesChannel: RealtimeChannelV2?
    private var tasksRealtimeSubscription: RealtimeSubscription?
    private var taskSharesRealtimeSubscription: RealtimeSubscription?
    
    func subscribeToSharedTasks() async {
        guard !didSubscribe, isNetworkAvailable else { return }
        didSubscribe = true
        
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id.uuidString
            
            // Subscribe to owned tasks (user_id = current user)
            let tasksCh = supabase.channel("tasks-\(userId)")
            tasksRealtimeSubscription = tasksCh.onPostgresChange(AnyAction.self, schema: "public", table: "tasks", filter: "user_id=eq.\(userId)") { [weak self] _ in
                _Concurrency.Task { @MainActor in
                    await self?.pullTasks()
                }
            }
            tasksChannel = tasksCh
            try await tasksCh.subscribeWithError()
            
            // Subscribe to task_shares where we're the recipient (shared_with_id = current user)
            let sharesCh = supabase.channel("task-shares-\(userId)")
            taskSharesRealtimeSubscription = sharesCh.onPostgresChange(AnyAction.self, schema: "public", table: "task_shares", filter: "shared_with_id=eq.\(userId)") { [weak self] _ in
                _Concurrency.Task { @MainActor in
                    await self?.pullTasks()
                }
            }
            taskSharesChannel = sharesCh
            try await sharesCh.subscribeWithError()
        } catch {
            print("Realtime subscribe error: \(error)")
        }
    }
    
    // Remove a shared task from current user's list (deletes the share, not the task)
    func removeSharedTask(taskId: UUID) async {
        guard isNetworkAvailable else {
            print("Skipping removeSharedTask: network unavailable")
            return
        }
        
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id.uuidString
            
            try await supabase
                .from("task_shares")
                .delete()
                .eq("task_id", value: taskId.uuidString)
                .eq("shared_with_id", value: userId)
                .execute()
        } catch {
            print("Error removing shared task: \(error)")
        }
    }
    
    // Retry failed sync items with exponential backoff
    func retryFailedItems() async {
        guard isNetworkAvailable else {
            print("Skipping retryFailedItems: network unavailable")
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        let failedValue = SyncStatus.failed.rawValue
        let retryDelays: [TimeInterval] = [2.0, 8.0, 30.0] // Exponential backoff: 2s, 8s, 30s
        
        // Retry failed tasks
        let taskDescriptor = FetchDescriptor<Task>(
            predicate: #Predicate<Task> { task in
                task.syncStatus == failedValue
            }
        )
        let failedTasks = (try? modelContext.fetch(taskDescriptor)) ?? []
        
        for task in failedTasks {
            var success = false
            for (attempt, delay) in retryDelays.enumerated() {
                if attempt > 0 {
                    try? await _Concurrency.Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                
                await pushTask(task)
                
                if task.syncStatus == SyncStatus.synced.rawValue {
                    success = true
                    break
                } else if task.syncStatus != failedValue {
                    break
                }
            }
            
            if !success && task.syncStatus == failedValue {
                syncError = "Some tasks failed to sync after retries"
                print("Failed to sync task '\(task.title)' after \(retryDelays.count) attempts")
            }
        }
        
        // Retry failed grocery stores
        let storeDescriptor = FetchDescriptor<GroceryStore>(
            predicate: #Predicate<GroceryStore> { store in
                store.syncStatus == failedValue
            }
        )
        let failedStores = (try? modelContext.fetch(storeDescriptor)) ?? []
        
        for store in failedStores {
            var success = false
            for (attempt, delay) in retryDelays.enumerated() {
                if attempt > 0 {
                    try? await _Concurrency.Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                
                await pushGroceryStore(store)
                
                if store.syncStatus == SyncStatus.synced.rawValue {
                    success = true
                    break
                } else if store.syncStatus != failedValue {
                    break
                }
            }
            
            if !success && store.syncStatus == failedValue {
                syncError = "Some stores failed to sync after retries"
                print("Failed to sync store '\(store.name)' after \(retryDelays.count) attempts")
            }
        }
        
        // Retry failed ingredients
        let ingredientDescriptor = FetchDescriptor<IngredientLibrary>(
            predicate: #Predicate<IngredientLibrary> { ingredient in
                ingredient.syncStatus == failedValue
            }
        )
        let failedIngredients = (try? modelContext.fetch(ingredientDescriptor)) ?? []
        
        for ingredient in failedIngredients {
            var success = false
            for (attempt, delay) in retryDelays.enumerated() {
                if attempt > 0 {
                    try? await _Concurrency.Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                
                await pushIngredient(ingredient)
                
                if ingredient.syncStatus == SyncStatus.synced.rawValue {
                    success = true
                    break
                } else if ingredient.syncStatus != failedValue {
                    break
                }
            }
            
            if !success && ingredient.syncStatus == failedValue {
                syncError = "Some ingredients failed to sync after retries"
                print("Failed to sync ingredient '\(ingredient.name)' after \(retryDelays.count) attempts")
            }
        }
    }
}

struct TaskShareRow: Codable {
    let taskId: UUID
    let ownerId: UUID
    
    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case ownerId = "owner_id"
    }
}
