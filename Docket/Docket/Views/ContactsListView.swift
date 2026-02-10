import SwiftUI
import ContactsUI
import Supabase
import _Concurrency

struct ContactsListView: View {
    @Environment(SyncEngine.self) private var syncEngine
    @State private var contacts: [ContactRow] = []
    @State private var pendingInvites: [PendingInviteRow] = []
    @State private var newEmail: String = ""
    @State private var newPhone: String = ""
    @State private var newName: String = ""
    @State private var statusMessage: String?
    @State private var showContactPicker = false
    @State private var showAddManual = false
    
    var body: some View {
        List {
            // MARK: - Pending Invites
            if !pendingInvites.isEmpty {
                Section {
                    ForEach(pendingInvites) { invite in
                        pendingInviteRow(invite)
                    }
                } header: {
                    Text("Pending Invites")
                }
            }
            
            // MARK: - Import & Add buttons
            Section {
                Button {
                    showContactPicker = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.title3)
                            .foregroundStyle(.blue)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import from Contacts")
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Add from your phone contacts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                
                if showAddManual {
                    AddContactFormView(
                        name: $newName,
                        email: $newEmail,
                        phone: $newPhone,
                        onSave: { addContact() },
                        onCancel: {
                            showAddManual = false
                            newName = ""
                            newEmail = ""
                            newPhone = ""
                        }
                    )
                } else {
                    Button {
                        showAddManual = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle")
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Add Manually")
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text("Enter contact details")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // MARK: - Contact list
            Section {
                if contacts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.slash")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("No contacts yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ForEach(contacts) { contact in
                        contactRow(contact)
                    }
                    .onDelete(perform: deleteContacts)
                }
            } header: {
                Text("Contacts (\(contacts.count))")
            }
            
            if let statusMessage = statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("My Contacts")
        .onAppear {
            loadContacts()
            loadPendingInvites()
        }
        .refreshable {
            await loadContactsAsync()
            await loadPendingInvitesAsync()
        }
        .sheet(isPresented: $showContactPicker) {
            NativeContactPicker { selectedContacts in
                importContacts(selectedContacts)
            }
        }
    }
    
    // MARK: - Pending Invite Row
    
    private func pendingInviteRow(_ invite: PendingInviteRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "checklist.badge.plus")
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(invite.taskTitle)
                        .font(.body)
                        .fontWeight(.medium)
                    Text("\(invite.ownerName ?? "Someone") wants to share this task with you")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack(spacing: 12) {
                Button {
                    acceptInvite(invite)
                } label: {
                    Text("Accept")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                Button {
                    declineInvite(invite)
                } label: {
                    Text("Decline")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
    
    private func acceptInvite(_ invite: PendingInviteRow) {
        _Concurrency.Task {
            do {
                try await SupabaseConfig.client
                    .from("task_shares")
                    .update(["status": "accepted"])
                    .eq("id", value: invite.id.uuidString)
                    .execute()
                await loadPendingInvitesAsync()
                await syncEngine.syncAll()
            } catch {
                print("Accept invite error: \(error)")
            }
        }
    }
    
    private func declineInvite(_ invite: PendingInviteRow) {
        _Concurrency.Task {
            do {
                try await SupabaseConfig.client
                    .from("task_shares")
                    .update(["status": "declined"])
                    .eq("id", value: invite.id.uuidString)
                    .execute()
                await loadPendingInvitesAsync()
            } catch {
                print("Decline invite error: \(error)")
            }
        }
    }
    
    private func loadPendingInvites() {
        _Concurrency.Task {
            await loadPendingInvitesAsync()
        }
    }
    
    private func loadPendingInvitesAsync() async {
        do {
            let session = try await SupabaseConfig.client.auth.session
            let userId = session.user.id.uuidString
            
            struct TaskShareBasic: Codable {
                let id: UUID
                let taskId: UUID
                let ownerId: UUID
                enum CodingKeys: String, CodingKey {
                    case id
                    case taskId = "task_id"
                    case ownerId = "owner_id"
                }
            }
            
            let shares: [TaskShareBasic] = try await SupabaseConfig.client
                .from("task_shares")
                .select("id, task_id, owner_id")
                .eq("shared_with_id", value: userId)
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .execute()
                .value
            
            guard !shares.isEmpty else {
                pendingInvites = []
                return
            }
            
            let taskIds = shares.map { $0.taskId }
            let ownerIds = Array(Set(shares.map { $0.ownerId }))
            
            struct TaskTitleRow: Codable {
                let id: UUID
                let title: String
            }
            struct OwnerProfileRow: Codable {
                let id: UUID
                let displayName: String?
                let email: String?
                enum CodingKeys: String, CodingKey {
                    case id
                    case displayName = "display_name"
                    case email
                }
            }
            
            let tasks: [TaskTitleRow] = (try? await SupabaseConfig.client
                .from("tasks")
                .select("id, title")
                .in("id", values: taskIds.map { $0.uuidString })
                .execute()
                .value) ?? []
            let profiles: [OwnerProfileRow] = (try? await SupabaseConfig.client
                .from("user_profiles")
                .select("id, display_name, email")
                .in("id", values: ownerIds.map { $0.uuidString })
                .execute()
                .value) ?? []
            
            let taskById = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.title) })
            let profileById = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0.displayName ?? $0.email ?? "Unknown") })
            
            pendingInvites = shares.map { share in
                PendingInviteRow(
                    id: share.id,
                    taskId: share.taskId,
                    taskTitle: taskById[share.taskId] ?? "Untitled Task",
                    ownerId: share.ownerId,
                    ownerName: profileById[share.ownerId]
                )
            }
        } catch {
            pendingInvites = []
        }
    }
    
    // MARK: - Contact Row
    
    private func contactRow(_ contact: ContactRow) -> some View {
        HStack(spacing: 12) {
            // Avatar circle with initial
            let initial = (contact.contactName?.prefix(1) ?? contact.contactEmail.prefix(1)).uppercased()
            Text(initial)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.8))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 3) {
                Text(contact.contactName ?? contact.contactEmail)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text(contact.contactEmail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if let phone = contact.contactPhone, !phone.isEmpty {
                    Text(phone)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Source indicator for imported contacts
            if contact.contactPhone != nil {
                Image(systemName: "person.crop.rectangle.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Data
    
    private func loadContacts() {
        _Concurrency.Task {
            await loadContactsAsync()
        }
    }
    
    private func loadContactsAsync() async {
        do {
            let session = try await SupabaseConfig.client.auth.session
            let userId = session.user.id.uuidString
            let response: [ContactRow] = try await SupabaseConfig.client
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
    
    private func addContact() {
        let email = newEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = newPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.isValidEmail else { return }
        
        // Check for local duplicate before hitting the DB
        if contacts.contains(where: { $0.contactEmail.lowercased() == email }) {
            statusMessage = "This contact already exists."
            return
        }
        
        _Concurrency.Task {
            do {
                let session = try await SupabaseConfig.client.auth.session
                let userId = session.user.id.uuidString
                let insert = ContactInsert(
                    userId: userId,
                    contactEmail: email,
                    contactName: name.isEmpty ? nil : name,
                    contactPhone: phone.isEmpty ? nil : phone
                )
                try await SupabaseConfig.client
                    .from("contacts")
                    .insert(insert)
                    .execute()
                
                newEmail = ""
                newName = ""
                newPhone = ""
                showAddManual = false
                statusMessage = nil
                loadContacts()
            } catch {
                print("Add contact error: \(error)")
                if "\(error)".contains("duplicate") || "\(error)".contains("unique") {
                    statusMessage = "This contact already exists."
                } else {
                    statusMessage = "Unable to add contact: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func importContacts(_ selectedContacts: [(name: String, email: String, phone: String)]) {
        _Concurrency.Task {
            do {
                let session = try await SupabaseConfig.client.auth.session
                let userId = session.user.id.uuidString
                
                var imported = 0
                for contact in selectedContacts {
                    let email = contact.email.trimmingCharacters(in: .whitespacesAndNewlines)
                    let name = contact.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let phone = contact.phone.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Skip if no email
                    guard !email.isEmpty else { continue }
                    
                    // Skip if already exists
                    if contacts.contains(where: { $0.contactEmail.lowercased() == email.lowercased() }) {
                        continue
                    }
                    
                    let insert = ContactInsert(
                        userId: userId,
                        contactEmail: email,
                        contactName: name.isEmpty ? nil : name,
                        contactPhone: phone.isEmpty ? nil : phone
                    )
                    
                    do {
                        try await SupabaseConfig.client
                            .from("contacts")
                            .insert(insert)
                            .execute()
                        imported += 1
                    } catch {
                        // Skip duplicates silently
                    }
                }
                
                if imported > 0 {
                    statusMessage = "\(imported) contact\(imported == 1 ? "" : "s") imported."
                } else if !selectedContacts.isEmpty {
                    statusMessage = "Contacts already added or missing email."
                }
                
                loadContacts()
            } catch {
                statusMessage = "Import failed."
            }
        }
    }
    
    private func deleteContacts(at offsets: IndexSet) {
        let ids = offsets.map { contacts[$0].id }
        contacts.remove(atOffsets: offsets)
        
        _Concurrency.Task {
            for id in ids {
                _ = try? await SupabaseConfig.client
                    .from("contacts")
                    .delete()
                    .eq("id", value: id.uuidString)
                    .execute()
            }
        }
    }
}

// MARK: - Pending Invite Row Model

struct PendingInviteRow: Identifiable {
    let id: UUID
    let taskId: UUID
    let taskTitle: String
    let ownerId: UUID
    let ownerName: String?
}

// MARK: - Contact Row Model

struct ContactRow: Codable, Identifiable {
    let id: UUID
    let contactEmail: String
    let contactName: String?
    let contactPhone: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case contactEmail = "contact_email"
        case contactName = "contact_name"
        case contactPhone = "contact_phone"
    }
}

// MARK: - Native Contact Picker (uses Apple's CNContactPickerViewController)

struct NativeContactPicker: UIViewControllerRepresentable {
    let onSelect: ([(name: String, email: String, phone: String)]) -> Void
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelect: ([(name: String, email: String, phone: String)]) -> Void
        
        init(onSelect: @escaping ([(name: String, email: String, phone: String)]) -> Void) {
            self.onSelect = onSelect
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            let results = contacts.map { contact in
                let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
                let email = contact.emailAddresses.first?.value as String? ?? ""
                let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
                return (name: name, email: email, phone: phone)
            }
            onSelect(results)
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onSelect([])
        }
    }
}

// MARK: - Shared Add Contact Form

struct AddContactFormView: View {
    @Binding var name: String
    @Binding var email: String
    @Binding var phone: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    private var isValid: Bool {
        email.trimmingCharacters(in: .whitespacesAndNewlines).isValidEmail
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "person.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                TextField("Name", text: $name)
                    .font(.body)
                    .textInputAutocapitalization(.words)
            }
            
            Divider()
            
            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                TextField("Email", text: $email)
                    .font(.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
            }
            
            Divider()
            
            HStack(spacing: 12) {
                Image(systemName: "phone.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                TextField("Phone (optional)", text: $phone)
                    .font(.body)
                    .keyboardType(.phonePad)
            }
            
            HStack(spacing: 16) {
                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Button {
                    onSave()
                } label: {
                    Text("Save Contact")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(isValid ? Color.blue : Color.gray)
                        .clipShape(Capsule())
                }
                .buttonStyle(.borderless)
                .disabled(!isValid)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ContactsListView()
    }
}
