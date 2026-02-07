import SwiftUI
import Supabase
import _Concurrency

struct ShareTaskView: View {
    @Environment(\.dismiss) private var dismiss
    
    let task: Task
    
    @State private var contacts: [ContactRecord] = []
    @State private var emailInput: String = ""
    @State private var isSharing = false
    @State private var statusMessage: String?
    
    var body: some View {
        NavigationStack {
            List {
                if !contacts.isEmpty {
                    Section("Contacts") {
                        ForEach(contacts) { contact in
                            Button {
                                share(to: contact.contactEmail, name: contact.contactName)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(contact.contactName ?? contact.contactEmail)
                                        if let name = contact.contactName {
                                            Text(contact.contactEmail)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "square.and.arrow.up")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Section("Invite") {
                    HStack(spacing: 8) {
                        TextField("Email or phone", text: $emailInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Share") {
                            share(to: emailInput, name: nil)
                        }
                        .disabled(emailInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSharing)
                    }
                }
                
                if let statusMessage = statusMessage {
                    Section {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Share Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadContacts()
            }
        }
    }
    
    private func loadContacts() {
        _Concurrency.Task {
            do {
                let session = try await SupabaseConfig.client.auth.session
                let userId = session.user.id.uuidString
                let response: [ContactRecord] = try await SupabaseConfig.client
                    .from("contacts")
                    .select()
                    .eq("user_id", value: userId)
                    .order("created_at", ascending: false)
                    .execute()
                    .value
                contacts = response
            } catch {
                contacts = []
            }
        }
    }
    
    private func share(to emailOrPhone: String, name: String?) {
        let trimmed = emailOrPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        isSharing = true
        statusMessage = nil
        
        _Concurrency.Task {
            defer { isSharing = false }
            do {
                let session = try await SupabaseConfig.client.auth.session
                let ownerId = session.user.id.uuidString
                
                let share = TaskShareInsert(
                    taskId: task.id,
                    ownerId: ownerId,
                    sharedWithEmail: trimmed,
                    status: "pending"
                )
                
                try await SupabaseConfig.client
                    .from("task_shares")
                    .insert(share)
                    .execute()
                
                await saveContactIfNeeded(email: trimmed, name: name, userId: ownerId)
                
                statusMessage = "Invite sent."
                emailInput = ""
            } catch {
                statusMessage = "Unable to share right now."
            }
        }
    }
    
    private func saveContactIfNeeded(email: String, name: String?, userId: String) async {
        let lowercased = email.lowercased()
        if contacts.contains(where: { $0.contactEmail.lowercased() == lowercased }) {
            return
        }
        
        let newContact = ContactInsert(
            userId: userId,
            contactEmail: email,
            contactName: name
        )
        
        do {
            try await SupabaseConfig.client
                .from("contacts")
                .insert(newContact)
                .execute()
            loadContacts()
        } catch {
            // ignore
        }
    }
}

struct ContactRecord: Codable, Identifiable {
    let id: UUID
    let contactEmail: String
    let contactName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case contactEmail = "contact_email"
        case contactName = "contact_name"
    }
}

struct TaskShareInsert: Encodable {
    let taskId: UUID
    let ownerId: String
    let sharedWithEmail: String
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case ownerId = "owner_id"
        case sharedWithEmail = "shared_with_email"
        case status
    }
}

struct ContactInsert: Encodable {
    let userId: String
    let contactEmail: String
    let contactName: String?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case contactEmail = "contact_email"
        case contactName = "contact_name"
    }
}

#Preview {
    ShareTaskView(task: Task(title: "Sample Task"))
}
