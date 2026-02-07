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
            
            let sharedIds: [UUID] = {
                do {
                    let shares: [TaskShareRow] = try await supabase
                        .from("task_shares")
                        .select()
                        .eq("shared_with_id", value: userId)
                        .eq("status", value: "accepted")
                        .execute()
                        .value
                    return shares.map { $0.taskId }
                } catch {
                    return []
                }
            }()
            
            let sharedResponse: [TaskDTO] = {
                guard !sharedIds.isEmpty else { return [] }
                do {
                    return try await supabase
                        .from("tasks")
                        .select()
                        .in("id", values: sharedIds.map { $0.uuidString })
                        .execute()
                        .value
                } catch {
                    return []
                }
            }()
            
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
            lastSyncDate = Date()
        } catch {
            syncError = error.localizedDescription
            print("Pull error: \(error)")
        }
    }
    
    // Push a single task to Supabase
    func pushTask(_ task: Task) async {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id.uuidString
            
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
    
    // Full sync: pull then push
    func syncAll() async {
        await pullTasks()
        await pushPendingTasks()
        await subscribeToSharedTasks()
    }
    
    func subscribeToSharedTasks() async {
        guard !didSubscribe else { return }
        didSubscribe = true
        // Placeholder for realtime subscriptions; keep sync polling for now.
    }
}

struct TaskShareRow: Codable {
    let taskId: UUID
    
    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
    }
}
