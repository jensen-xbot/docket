import SwiftUI
import Contacts
import Supabase
import _Concurrency

struct ContactsListView: View {
    @State private var contacts: [ContactRow] = []
    @State private var newEmail: String = ""
    @State private var newPhone: String = ""
    @State private var newName: String = ""
    @State private var statusMessage: String?
    @State private var showContactPicker = false
    
    var body: some View {
        List {
            Section("Add Contact") {
                TextField("Name (optional)", text: $newName)
                    .textInputAutocapitalization(.words)
                TextField("Email", text: $newEmail)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                TextField("Phone (optional)", text: $newPhone)
                    .keyboardType(.phonePad)
                
                HStack {
                    Button("Add") {
                        addContact()
                    }
                    .disabled(newEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Spacer()
                    
                    Button {
                        importFromContacts()
                    } label: {
                        Label("Import", systemImage: "person.crop.circle.badge.plus")
                    }
                }
            }
            
            Section("Contacts (\(contacts.count))") {
                ForEach(contacts) { contact in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.contactName ?? contact.contactEmail)
                        if contact.contactName != nil {
                            Text(contact.contactEmail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let phone = contact.contactPhone, !phone.isEmpty {
                            Text(phone)
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
        .sheet(isPresented: $showContactPicker) {
            PhoneContactPickerView { name, email, phone in
                newName = name
                newEmail = email
                newPhone = phone
                showContactPicker = false
                if !email.isEmpty {
                    addContact()
                }
            }
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
        let phone = newPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return }
        
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
                statusMessage = "Contact added."
                loadContacts()
            } catch {
                statusMessage = "Unable to add contact."
            }
        }
    }
    
    private func importFromContacts() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    showContactPicker = true
                }
            } else {
                DispatchQueue.main.async {
                    statusMessage = "Please allow Contacts access in Settings."
                }
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
    let contactPhone: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case contactEmail = "contact_email"
        case contactName = "contact_name"
        case contactPhone = "contact_phone"
    }
}

// Simple phone contact picker
struct PhoneContactPickerView: View {
    let onSelect: (String, String, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var phoneContacts: [(name: String, email: String, phone: String)] = []
    @State private var searchText = ""
    
    private var filtered: [(name: String, email: String, phone: String)] {
        if searchText.isEmpty { return phoneContacts }
        return phoneContacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.email.localizedCaseInsensitiveContains(searchText) ||
            $0.phone.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            List(filtered, id: \.email) { contact in
                Button {
                    onSelect(contact.name, contact.email, contact.phone)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.name)
                        if !contact.email.isEmpty {
                            Text(contact.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !contact.phone.isEmpty {
                            Text(contact.phone)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Import Contact")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search contacts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { fetchPhoneContacts() }
        }
    }
    
    private func fetchPhoneContacts() {
        let store = CNContactStore()
        let keys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactEmailAddressesKey,
            CNContactPhoneNumbersKey
        ] as [CNKeyDescriptor]
        
        var results: [(name: String, email: String, phone: String)] = []
        let request = CNContactFetchRequest(keysToFetch: keys)
        
        do {
            try store.enumerateContacts(with: request) { contact, _ in
                let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
                let email = contact.emailAddresses.first?.value as String? ?? ""
                let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
                
                // Only include contacts with at least an email
                if !email.isEmpty {
                    results.append((name: fullName, email: email, phone: phone))
                }
            }
            phoneContacts = results.sorted { $0.name < $1.name }
        } catch {
            phoneContacts = []
        }
    }
}

#Preview {
    NavigationStack {
        ContactsListView()
    }
}
