import SwiftUI
import MessageUI
import Supabase
import _Concurrency

// MARK: - ShareTaskView

@MainActor
struct ShareTaskView: View {
    @Environment(\.dismiss) private var dismiss
    
    let task: Task
    
    @State private var contacts: [ContactRecord] = []
    @State private var isSharing = false
    @State private var statusMessage: String?
    
    // Share method selection
    @State private var selectedContact: ContactRecord? = nil
    @State private var showMethodPicker = false
    
    // Compose sheets
    @State private var showMailCompose = false
    @State private var showTextCompose = false
    @State private var composeRecipient: String = ""
    @State private var composeSubject: String = ""
    @State private var composeBody: String = ""
    @State private var composeEmail: String = "" // always the email, even when texting
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
                                    Text(contact.contactName ?? contact.contactEmail)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    // Docket membership indicator
                                    if contact.contactUserId != nil {
                                        Image(systemName: "checklist")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    } else {
                                        Image(systemName: "person.circle")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }
                                    
                                    Image(systemName: "paperplane.fill")
                                        .foregroundStyle(.blue)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
                
                // Manage contacts link
                Section {
                    NavigationLink {
                        ContactsListView()
                            .onDisappear { loadContacts() }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.2.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Manage Contacts")
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text("Import, add, or edit contacts")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
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
            .sheet(isPresented: $showMethodPicker) {
                if let contact = selectedContact {
                    ShareMethodSheet(
                        contact: contact,
                        onEmail: {
                            showMethodPicker = false
                            prepareAndShare(email: contact.contactEmail, viaText: false)
                        },
                        onText: {
                            showMethodPicker = false
                            prepareAndShare(phone: contact.contactPhone, viaText: true)
                        },
                        onDocket: {
                            showMethodPicker = false
                            shareViaDocket(contact: contact)
                        },
                        onCancel: {
                            showMethodPicker = false
                            selectedContact = nil
                        }
                    )
                    .presentationDetents([.height(280)])
                    .presentationDragIndicator(.visible)
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
                        // Use the email for the share record, not the phone number
                        if !composeEmail.isEmpty {
                            recordShare(to: composeEmail)
                        }
                        statusMessage = "Text sent."
                    }
                }
            }
        }
        .interactiveDismissDisabled(false)
    }
    
    // MARK: - Contact tap → pick method
    
    private func handleContactTap(_ contact: ContactRecord) {
        selectedContact = contact
        showMethodPicker = true
    }
    
    // MARK: - Prepare share content
    
    private func prepareAndShare(email: String? = nil, phone: String? = nil, viaText: Bool) {
        isSharing = true
        statusMessage = nil
        
        _Concurrency.Task {
            defer { isSharing = false }
            
            // Resolve the email: use passed email, or look up from selectedContact
            let recipientEmail: String
            if let email, !email.isEmpty {
                recipientEmail = email
            } else if let contact = selectedContact {
                recipientEmail = contact.contactEmail
            } else {
                recipientEmail = ""
            }
            
            // Always store the email for share records
            composeEmail = recipientEmail
            
            // Check if user exists in our system
            let userExists = await checkUserExists(email: recipientEmail)
            
            if viaText {
                // Strip phone number to digits only (and optional leading +)
                let cleanedPhone = stripPhoneNumber(phone ?? "")
                composeRecipient = cleanedPhone
                if userExists {
                    composeBody = "I shared \"\(task.title)\" with you on Docket. Open the app to see it!"
                } else {
                    composeBody = "I shared \"\(task.title)\" with you on Docket. Download it here: \(appStoreURL)"
                }
                isExistingUser = userExists
                showTextCompose = true
            } else {
                composeRecipient = recipientEmail
                composeSubject = "Task shared: \(task.title)"
                if userExists {
                    composeBody = "I shared \"\(task.title)\" with you on Docket. Open the app to see it!"
                } else {
                    composeBody = "I shared \"\(task.title)\" with you on Docket. Download it here: \(appStoreURL)"
                }
                isExistingUser = userExists
                showMailCompose = true
            }
            
            // Resolve contact_user_id if recipient is a Docket user
            if userExists, let userId = await getUserIdForEmail(recipientEmail) {
                await updateContactUserId(email: recipientEmail, userId: userId)
            }
        }
    }
    
    // MARK: - Share via Docket
    
    private func shareViaDocket(contact: ContactRecord) {
        guard contact.contactUserId != nil else { return }
        
        isSharing = true
        statusMessage = nil
        
        _Concurrency.Task {
            defer { isSharing = false }
            
            do {
                let session = try await SupabaseConfig.client.auth.session
                let ownerId = session.user.id.uuidString
                
                let shareInsert = TaskShareInsert(
                    taskId: task.id,
                    ownerId: ownerId,
                    sharedWithEmail: contact.contactEmail,
                    status: "pending"
                )
                
                try await SupabaseConfig.client
                    .from("task_shares")
                    .insert(shareInsert)
                    .execute()
                
                let contactName = contact.contactName ?? contact.contactEmail
                statusMessage = "Shared with \(contactName) on Docket."
                selectedContact = nil
            } catch {
                statusMessage = "Couldn't share via Docket. Please try again."
            }
        }
    }
    
    // MARK: - Phone number formatting
    
    private func stripPhoneNumber(_ phone: String) -> String {
        // Keep only digits and optional leading +
        let cleaned = phone.filter { $0.isNumber || $0 == "+" }
        // Ensure + is only at the start
        if cleaned.hasPrefix("+") {
            return "+" + cleaned.dropFirst().filter { $0.isNumber }
        }
        return cleaned.filter { $0.isNumber }
    }
    
    // MARK: - Check if user exists
    
    private func checkUserExists(email: String) async -> Bool {
        guard !email.isEmpty else { return false }
        do {
            struct UserLookup: Codable { let id: UUID }
            let result: [UserLookup] = try await SupabaseConfig.client
                .from("user_profiles")
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
    
    private func getUserIdForEmail(_ email: String) async -> String? {
        guard !email.isEmpty else { return nil }
        do {
            struct UserLookup: Codable { let id: UUID }
            let result: [UserLookup] = try await SupabaseConfig.client
                .from("user_profiles")
                .select("id")
                .eq("email", value: email.lowercased())
                .limit(1)
                .execute()
                .value
            return result.first?.id.uuidString
        } catch {
            return nil
        }
    }
    
    private func updateContactUserId(email: String, userId: String) async {
        do {
            let session = try await SupabaseConfig.client.auth.session
            let currentUserId = session.user.id.uuidString
            
            try await SupabaseConfig.client
                .from("contacts")
                .update(["contact_user_id": userId])
                .eq("user_id", value: currentUserId)
                .eq("contact_email", value: email.lowercased())
                .execute()
            
            // Reload contacts to update UI
            loadContacts()
        } catch {
            // Ignore errors - contact might not exist yet
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
                
                // Lazy resolve membership for contacts without contact_user_id
                for contact in contacts where contact.contactUserId == nil {
                    if await checkUserExists(email: contact.contactEmail),
                       let userId = await getUserIdForEmail(contact.contactEmail) {
                        await updateContactUserId(email: contact.contactEmail, userId: userId)
                    }
                }
            } catch {
                contacts = []
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
    let onFinish: @MainActor (MFMailComposeResult) -> Void
    
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
        let onFinish: @MainActor (MFMailComposeResult) -> Void
        init(onFinish: @escaping @MainActor (MFMailComposeResult) -> Void) { self.onFinish = onFinish }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            _Concurrency.Task {
                await MainActor.run {
                    onFinish(result)
                    controller.dismiss(animated: true)
                }
            }
        }
    }
}

// MARK: - Text Message Compose UIKit wrapper

struct TextComposeView: UIViewControllerRepresentable {
    let recipient: String
    let body: String
    let onFinish: @MainActor (MessageComposeResult) -> Void
    
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.messageComposeDelegate = context.coordinator
        // recipient is already cleaned (digits only)
        vc.recipients = [recipient]
        vc.body = body
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }
    
    class Coordinator: NSObject, @unchecked Sendable, MFMessageComposeViewControllerDelegate {
        let onFinish: @MainActor (MessageComposeResult) -> Void
        init(onFinish: @escaping @MainActor (MessageComposeResult) -> Void) { self.onFinish = onFinish }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            _Concurrency.Task {
                await MainActor.run {
                    onFinish(result)
                    controller.dismiss(animated: true)
                }
            }
        }
    }
}

// MARK: - Models

struct ContactRecord: Codable, Identifiable {
    let id: UUID
    let contactEmail: String
    let contactName: String?
    let contactPhone: String?
    let contactUserId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case id
        case contactEmail = "contact_email"
        case contactName = "contact_name"
        case contactPhone = "contact_phone"
        case contactUserId = "contact_user_id"
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

// MARK: - Share Method Sheet (replaces confirmationDialog to avoid constraint warnings)

private struct ShareMethodSheet: View {
    let contact: ContactRecord
    let onEmail: () -> Void
    let onText: () -> Void
    let onDocket: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Contact name header
                Text(contact.contactName ?? contact.contactEmail)
                    .font(.headline)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                
                VStack(spacing: 12) {
                    // Email option
                    Button {
                        onEmail()
                    } label: {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .frame(width: 24)
                            Text("Email")
                            Spacer()
                            Text(contact.contactEmail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    
                    // Text option (only if phone exists)
                    if let phone = contact.contactPhone, !phone.isEmpty {
                        Button {
                            onText()
                        } label: {
                            HStack {
                                Image(systemName: "message.fill")
                                    .frame(width: 24)
                                Text("Text Message")
                                Spacer()
                                Text(phone)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Share via Docket (always visible, greyed if not a member)
                    let isMember = contact.contactUserId != nil
                    Button {
                        if isMember { onDocket() }
                    } label: {
                        HStack {
                            Image(systemName: "checklist")
                                .frame(width: 24)
                            Text("Share via Docket")
                            Spacer()
                            if !isMember {
                                Text("Not a member")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(isMember ? .blue : .gray.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .disabled(!isMember)
                }
                .padding(.horizontal, 16)
                
                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Share via")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
    }
}

#Preview {
    ShareTaskView(task: Task(title: "Sample Task"))
}
