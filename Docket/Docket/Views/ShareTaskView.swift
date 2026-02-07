import SwiftUI
import MessageUI
import Supabase
import _Concurrency

// MARK: - Share Method

enum ShareMethod: String, CaseIterable {
    case email = "Email"
    case text = "Text"
}

// MARK: - ShareTaskView

struct ShareTaskView: View {
    @Environment(\.dismiss) private var dismiss
    
    let task: Task
    
    @State private var contacts: [ContactRecord] = []
    @State private var emailInput: String = ""
    @State private var isSharing = false
    @State private var statusMessage: String?
    @State private var showAddContact = false
    @State private var newName: String = ""
    @State private var newEmail: String = ""
    @State private var newPhone: String = ""
    
    // Share method selection
    @State private var selectedContact: ContactRecord? = nil
    @State private var showMethodPicker = false
    
    // Compose sheets
    @State private var showMailCompose = false
    @State private var showTextCompose = false
    @State private var composeRecipient: String = ""
    @State private var composeSubject: String = ""
    @State private var composeBody: String = ""
    @State private var isExistingUser = false
    
    private let appStoreURL = "https://apps.apple.com/app/docket/id0000000000" // Replace with real ID
    
    var body: some View {
        NavigationStack {
            List {
                // Pick from existing contacts
                if !contacts.isEmpty {
                    Section("Share with a Contact") {
                        ForEach(contacts) { contact in
                            Button {
                                handleContactTap(contact)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(contact.contactName ?? contact.contactEmail)
                                            .font(.body)
                                            .fontWeight(.medium)
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
                                    Image(systemName: "paperplane.fill")
                                        .foregroundStyle(.blue)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
                
                // Or type an email/phone directly
                Section("Share by Email or Phone") {
                    HStack(spacing: 8) {
                        TextField("Email or phone", text: $emailInput)
                            .font(.body)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                        Button("Send") {
                            handleManualShare()
                        }
                        .disabled(emailInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSharing)
                    }
                }
                
                // Add new contact inline
                Section {
                    if showAddContact {
                        VStack(spacing: 8) {
                            TextField("Name", text: $newName)
                                .font(.body)
                                .textInputAutocapitalization(.words)
                            TextField("Email", text: $newEmail)
                                .font(.body)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.emailAddress)
                            TextField("Phone (optional)", text: $newPhone)
                                .font(.body)
                                .keyboardType(.phonePad)
                            HStack {
                                Button("Save Contact") {
                                    addContact()
                                }
                                .disabled(newEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                
                                Spacer()
                                
                                Button("Cancel") {
                                    showAddContact = false
                                    newName = ""
                                    newEmail = ""
                                    newPhone = ""
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Button {
                            showAddContact = true
                        } label: {
                            Label("Add New Contact", systemImage: "plus.circle")
                                .font(.body)
                        }
                    }
                }
                
                if let statusMessage = statusMessage {
                    Section {
                        Text(statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Share Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear { loadContacts() }
            .confirmationDialog("How would you like to share?", isPresented: $showMethodPicker, titleVisibility: .visible) {
                if let contact = selectedContact {
                    Button("Email (\(contact.contactEmail))") {
                        prepareAndShare(email: contact.contactEmail, viaText: false)
                    }
                    if let phone = contact.contactPhone, !phone.isEmpty {
                        Button("Text Message (\(phone))") {
                            prepareAndShare(phone: phone, viaText: true)
                        }
                    }
                    Button("Cancel", role: .cancel) { selectedContact = nil }
                }
            }
            .sheet(isPresented: $showMailCompose) {
                MailComposeView(
                    recipient: composeRecipient,
                    subject: composeSubject,
                    body: composeBody
                ) { result in
                    if case .sent = result {
                        recordShare(to: composeRecipient)
                        statusMessage = "Email sent to \(composeRecipient)."
                    }
                }
            }
            .sheet(isPresented: $showTextCompose) {
                TextComposeView(
                    recipient: composeRecipient,
                    body: composeBody
                ) { result in
                    if case .sent = result {
                        recordShare(to: composeRecipient)
                        statusMessage = "Text sent to \(composeRecipient)."
                    }
                }
            }
        }
        .interactiveDismissDisabled(false)
    }
    
    // MARK: - Contact tap → pick method
    
    private func handleContactTap(_ contact: ContactRecord) {
        let hasPhone = !(contact.contactPhone ?? "").isEmpty
        if hasPhone {
            selectedContact = contact
            showMethodPicker = true
        } else {
            // Only email available
            prepareAndShare(email: contact.contactEmail, viaText: false)
        }
    }
    
    private func handleManualShare() {
        let input = emailInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        
        if input.contains("@") {
            prepareAndShare(email: input, viaText: false)
        } else {
            prepareAndShare(phone: input, viaText: true)
        }
    }
    
    // MARK: - Prepare share content
    
    private func prepareAndShare(email: String? = nil, phone: String? = nil, viaText: Bool) {
        isSharing = true
        statusMessage = nil
        
        _Concurrency.Task {
            defer { isSharing = false }
            
            let recipientEmail = email ?? ""
            
            // Check if user exists in our system
            let userExists = await checkUserExists(email: recipientEmail)
            
            let senderName: String
            do {
                let session = try await SupabaseConfig.client.auth.session
                senderName = session.user.userMetadata["full_name"]
                    .flatMap { if case let .string(n) = $0 { return n } else { return nil } }
                    ?? session.user.email
                    ?? "Someone"
            } catch {
                senderName = "Someone"
            }
            
            if viaText {
                composeRecipient = phone ?? ""
                if userExists {
                    composeBody = "\(senderName) shared a task with you on Docket:\n\n\"\(task.title)\"\n\nOpen Docket to view it."
                } else {
                    composeBody = "\(senderName) wants to share a task with you:\n\n\"\(task.title)\"\n\nDownload Docket to collaborate:\n\(appStoreURL)"
                }
                isExistingUser = userExists
                showTextCompose = true
            } else {
                composeRecipient = recipientEmail
                composeSubject = "\(senderName) shared a task with you"
                if userExists {
                    composeBody = """
                    Hi,
                    
                    \(senderName) shared a task with you on Docket:
                    
                    "\(task.title)"
                    
                    Open the Docket app to view and collaborate on this task.
                    
                    — Sent from Docket
                    """
                } else {
                    composeBody = """
                    Hi,
                    
                    \(senderName) wants to share a task with you:
                    
                    "\(task.title)"
                    
                    To view and collaborate, download Docket:
                    \(appStoreURL)
                    
                    Once you sign up, the shared task will appear automatically.
                    
                    — Sent from Docket
                    """
                }
                isExistingUser = userExists
                showMailCompose = true
            }
        }
    }
    
    // MARK: - Check if user exists
    
    private func checkUserExists(email: String) async -> Bool {
        guard !email.isEmpty else { return false }
        do {
            struct UserLookup: Codable { let id: UUID }
            let result: [UserLookup] = try await SupabaseConfig.client
                .from("profiles")
                .select("id")
                .eq("email", value: email.lowercased())
                .limit(1)
                .execute()
                .value
            return !result.isEmpty
        } catch {
            // If profiles table doesn't exist or query fails, just return false
            return false
        }
    }
    
    // MARK: - Record the share in Supabase
    
    private func recordShare(to recipient: String) {
        _Concurrency.Task {
            do {
                let session = try await SupabaseConfig.client.auth.session
                let ownerId = session.user.id.uuidString
                
                let shareInsert = TaskShareInsert(
                    taskId: task.id,
                    ownerId: ownerId,
                    sharedWithEmail: recipient,
                    status: "pending"
                )
                
                try await SupabaseConfig.client
                    .from("task_shares")
                    .insert(shareInsert)
                    .execute()
                
                await saveContactIfNeeded(email: recipient, name: nil, userId: ownerId)
            } catch {
                // ignore
            }
        }
    }
    
    // MARK: - Contacts CRUD
    
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
                
                newName = ""
                newEmail = ""
                newPhone = ""
                showAddContact = false
                statusMessage = "Contact saved."
                loadContacts()
            } catch {
                statusMessage = "Couldn't save contact."
            }
        }
    }
    
    private func saveContactIfNeeded(email: String, name: String?, userId: String) async {
        let lowercased = email.lowercased()
        if contacts.contains(where: { $0.contactEmail.lowercased() == lowercased }) { return }
        
        let newContact = ContactInsert(
            userId: userId,
            contactEmail: email,
            contactName: name,
            contactPhone: nil
        )
        
        do {
            try await SupabaseConfig.client
                .from("contacts")
                .insert(newContact)
                .execute()
            loadContacts()
        } catch { }
    }
}

// MARK: - Mail Compose UIKit wrapper

struct MailComposeView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    let onFinish: @Sendable (MFMailComposeResult) -> Void
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }
    
    class Coordinator: NSObject, @unchecked Sendable, MFMailComposeViewControllerDelegate {
        let onFinish: @Sendable (MFMailComposeResult) -> Void
        init(onFinish: @escaping @Sendable (MFMailComposeResult) -> Void) { self.onFinish = onFinish }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            onFinish(result)
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - Text Message Compose UIKit wrapper

struct TextComposeView: UIViewControllerRepresentable {
    let recipient: String
    let body: String
    let onFinish: @Sendable (MessageComposeResult) -> Void
    
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.messageComposeDelegate = context.coordinator
        vc.recipients = [recipient]
        vc.body = body
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }
    
    class Coordinator: NSObject, @unchecked Sendable, MFMessageComposeViewControllerDelegate {
        let onFinish: @Sendable (MessageComposeResult) -> Void
        init(onFinish: @escaping @Sendable (MessageComposeResult) -> Void) { self.onFinish = onFinish }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            onFinish(result)
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - Models

struct ContactRecord: Codable, Identifiable {
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

#Preview {
    ShareTaskView(task: Task(title: "Sample Task"))
}
