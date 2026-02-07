import SwiftUI
import SwiftData
import _Concurrency

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var stores: [GroceryStore]
    
    var authManager: AuthManager
    
    @State private var userEmail: String = "—"
    @State private var userDisplayName: String = "Account"
    @State private var showSignOutConfirm = false
    @State private var contactCount: Int = 0
    
    @AppStorage("notifications.remindersEnabled") private var remindersEnabled = true
    @AppStorage("notifications.shareAlertsEnabled") private var shareAlertsEnabled = true
    @AppStorage("notifications.defaultReminderMinutes") private var defaultReminderMinutes = 0
    
    init(authManager: AuthManager) {
        self.authManager = authManager
        _stores = Query()
    }
    
    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(userDisplayName)
                            .font(.headline)
                        Text(userEmail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section("My Store Templates") {
                NavigationLink {
                    GroceryTemplateListView()
                } label: {
                    Label("Manage Store Lists", systemImage: "cart.fill")
                }
                Text("\(stores.count) stores saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Notifications") {
                Toggle("Task Reminders", isOn: $remindersEnabled)
                Toggle("Shared Task Alerts", isOn: $shareAlertsEnabled)
                if remindersEnabled {
                    Picker("Default Reminder", selection: $defaultReminderMinutes) {
                        Text("At time of event").tag(0)
                        Text("15 min before").tag(15)
                        Text("1 hour before").tag(60)
                        Text("1 day before").tag(1440)
                    }
                }
            }
            
            Section("My Contacts") {
                NavigationLink {
                    ContactsListView()
                } label: {
                    Label("Manage Contacts", systemImage: "person.2.fill")
                }
                Text("\(contactCount) contacts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section {
                Button("Sign Out", role: .destructive) {
                    showSignOutConfirm = true
                }
            }
        }
        .navigationTitle("Profile")
        .confirmationDialog("Sign out?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                _Concurrency.Task {
                    await authManager.signOut()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .onAppear {
            loadUserDetails()
            loadContactCount()
        }
    }
    
    private func loadUserDetails() {
        _Concurrency.Task {
            do {
                let session = try await SupabaseConfig.client.auth.session
                userEmail = session.user.email ?? "—"
                if let metadata = session.user.userMetadata["full_name"],
                   case let .string(name) = metadata,
                   !name.isEmpty {
                    userDisplayName = name
                } else {
                    userDisplayName = "Account"
                }
            } catch {
                userEmail = "—"
                userDisplayName = "Account"
            }
        }
    }
    
    private func loadContactCount() {
        _Concurrency.Task {
            do {
                let session = try await SupabaseConfig.client.auth.session
                let userId = session.user.id.uuidString
                let response: [ContactCountRow] = try await SupabaseConfig.client
                    .from("contacts")
                    .select()
                    .eq("user_id", value: userId)
                    .execute()
                    .value
                contactCount = response.count
            } catch {
                contactCount = 0
            }
        }
    }
}

struct ContactCountRow: Codable {
    let id: UUID
}

#Preview {
    ProfileView(authManager: AuthManager())
        .modelContainer(for: [Task.self, GroceryStore.self], inMemory: true)
}
