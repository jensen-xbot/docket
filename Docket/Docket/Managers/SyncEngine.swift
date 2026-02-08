import Foundation
import Supabase
import SwiftData

@MainActor
@Observable
class SyncEngine {
    private let supabase = SupabaseConfig.client
    private let modelContext: ModelContext
    
    var isSyncing = false
    var lastSyncDate: Date?
    var syncError: String?
    var sharerProfiles: [String: UserProfile] = [:]
    private var didSubscribe = false
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // Pull remote tasks and merge with local
    func pullTasks() async {
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
                        existing.isShared = false
                        existing.updatedAt = dto.updatedAt
                        existing.syncStatus = SyncStatus.synced.rawValue
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
    
    // Push a single task to Supabase
    func pushTask(_ task: Task) async {
        do {
            let session = try await supabase.auth.session
            let currentUserId = session.user.id.uuidString
            
            // For shared tasks, preserve the original owner's userId
            // For owned tasks, use current user's ID
            let userId = task.isShared && task.userId != nil ? task.userId! : currentUserId
            
            task.updatedAt = Date()
            let dto = TaskDTO(from: task, userId: userId)
            
            try await supabase
                .from("tasks")
                .upsert(dto, onConflict: "id")
                .execute()
            
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
    
    func subscribeToSharedTasks() async {
        guard !didSubscribe else { return }
        didSubscribe = true
        // Placeholder for realtime subscriptions; keep sync polling for now.
    }
    
    // Remove a shared task from current user's list (deletes the share, not the task)
    func removeSharedTask(taskId: UUID) async {
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
}

struct TaskShareRow: Codable {
    let taskId: UUID
    let ownerId: UUID
    
    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case ownerId = "owner_id"
    }
}
