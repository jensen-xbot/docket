import SwiftUI
import Supabase
import _Concurrency

struct ContactsListView: View {
    @State private var contacts: [ContactRow] = []
    @State private var newEmail: String = ""
    @State private var newName: String = ""
    @State private var statusMessage: String?
    
    var body: some View {
        List {
            Section("Add Contact") {
                TextField("Name (optional)", text: $newName)
                    .textInputAutocapitalization(.words)
                TextField("Email", text: $newEmail)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                Button("Add") {
                    addContact()
                }
                .disabled(newEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            Section("Contacts") {
                ForEach(contacts) { contact in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.contactName ?? contact.contactEmail)
                        if let name = contact.contactName {
                            Text(contact.contactEmail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteContacts)
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
        }
    }
    
    private func loadContacts() {
        _Concurrency.Task {
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
    }
    
    private func addContact() {
        let email = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return }
        
        _Concurrency.Task {
            do {
                let session = try await SupabaseConfig.client.auth.session
                let userId = session.user.id.uuidString
                let insert = ContactInsert(
                    userId: userId,
                    contactEmail: email,
                    contactName: name.isEmpty ? nil : name
                )
                try await SupabaseConfig.client
                    .from("contacts")
                    .insert(insert)
                    .execute()
                
                newEmail = ""
                newName = ""
                statusMessage = "Contact added."
                loadContacts()
            } catch {
                statusMessage = "Unable to add contact."
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

struct ContactRow: Codable, Identifiable {
    let id: UUID
    let contactEmail: String
    let contactName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case contactEmail = "contact_email"
        case contactName = "contact_name"
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
    NavigationStack {
        ContactsListView()
    }
}
