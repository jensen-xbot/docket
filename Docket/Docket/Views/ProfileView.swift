import SwiftUI
import SwiftData
import PhotosUI
import _Concurrency
import Supabase

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var stores: [GroceryStore]
    
    var authManager: AuthManager
    
    // Profile state
    @State private var profile: UserProfile?
    @State private var userId: UUID?
    @State private var authEmail: String = "—"
    
    // Editing state
    @State private var isEditing = false
    @State private var editName: String = ""
    @State private var editEmail: String = ""
    @State private var editPhone: String = ""
    @State private var editCountryIso: String = "US"
    @State private var editAvatarEmoji: String?
    @State private var editAvatarUrl: String?
    
    // Photo picker
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var showPhotoPicker = false
    
    // Sheets & alerts
    @State private var showEmojiPicker = false
    @State private var showAvatarOptions = false
    @State private var showCountryPicker = false
    @State private var showSignOutConfirm = false
    @State private var isSaving = false
    @State private var statusMessage: String?
    
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
            // MARK: - Profile Header Section
            Section {
                profileHeaderContent
            }
            
            // MARK: - My Stuff
            Section("My Library") {
                NavigationLink {
                    GroceryTemplateListView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "cart.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                            .frame(width: 32)
                        Text("Manage Store Templates")
                            .font(.body)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(stores.count)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(.vertical, 4)
                }
                
                NavigationLink {
                    ContactsListView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                            .frame(width: 32)
                        Text("Manage Contacts")
                            .font(.body)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(contactCount)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // MARK: - Notifications
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
            
            // MARK: - Sign Out
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
                    await authManager.signOut(modelContext: modelContext)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog("Profile Picture", isPresented: $showAvatarOptions, titleVisibility: .visible) {
            Button("Choose Photo") {
                showPhotoPicker = true
            }
            Button("Choose Emoji") {
                showEmojiPicker = true
            }
            if editAvatarEmoji != nil || editAvatarUrl != nil || avatarImage != nil {
                Button("Remove", role: .destructive) {
                    editAvatarEmoji = nil
                    editAvatarUrl = nil
                    avatarImage = nil
                    selectedPhoto = nil
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerView { emoji in
                editAvatarEmoji = emoji
                editAvatarUrl = nil
                avatarImage = nil
                selectedPhoto = nil
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryCodePickerView(selectedIsoCode: $editCountryIso)
                .presentationDetents([.medium, .large])
        }
        .onChange(of: selectedPhoto) { _, newItem in
            loadPhoto(from: newItem)
        }
        .onAppear {
            loadProfile()
            loadContactCount()
        }
    }
    
    // MARK: - Profile Header
    
    @ViewBuilder
    private var profileHeaderContent: some View {
        if isEditing {
            editModeContent
        } else {
            viewModeContent
        }
    }
    
    // MARK: - View Mode (tappable to edit)
    
    private var viewModeContent: some View {
        Button {
            beginEditing()
        } label: {
            HStack(spacing: 12) {
                avatarView(size: 52)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(displayEmail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let phone = profile?.phone, !phone.isEmpty {
                        HStack(spacing: 4) {
                            Text(countryFlag)
                            if let iso = profile?.countryIso, let country = CountryCodes.find(isoCode: iso) {
                                Text("\(country.dialCode) \(phone)")
                            } else {
                                Text("\(phone)")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Edit Mode (inline expanded)
    
    private var editModeContent: some View {
        VStack(spacing: 16) {
            // Avatar with "+" overlay
            Button {
                showAvatarOptions = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    avatarView(size: 72)
                    
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white, .blue)
                        .offset(x: 4, y: 4)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
            
            // Name field
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Your name", text: $editName)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
            }
            
            // Display email field
            VStack(alignment: .leading, spacing: 4) {
                Text("Email")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("your@email.com", text: $editEmail)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                if authEmail.contains("privaterelay.apple") {
                    Text("Your sign-in uses Apple Private Relay. Add a display email above.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Phone with country code
            VStack(alignment: .leading, spacing: 4) {
                Text("Phone")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button {
                        showCountryPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedCountry.flag)
                                .font(.title3)
                            Text(selectedCountry.dialCode)
                                .font(.subheadline)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    
                    TextField("Phone number", text: $editPhone)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.phonePad)
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    cancelEditing()
                }
                .foregroundStyle(.secondary)
                
                Spacer()
                
                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Save") {
                        saveProfile()
                    }
                    .fontWeight(.semibold)
                }
            }
            .padding(.top, 4)
            
            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(statusMessage.contains("Error") ? .red : .green)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.25), value: isEditing)
    }
    
    // MARK: - Avatar View
    
    @ViewBuilder
    private func avatarView(size: CGFloat) -> some View {
        let currentEmoji = isEditing ? editAvatarEmoji : profile?.avatarEmoji
        let currentUrl = isEditing ? editAvatarUrl : profile?.avatarUrl
        
        if let image = avatarImage, isEditing {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else if let emoji = currentEmoji, !emoji.isEmpty {
            Text(emoji)
                .font(.system(size: size * 0.6))
                .frame(width: size, height: size)
                .background(Color(.secondarySystemFill))
                .clipShape(Circle())
        } else if let urlString = currentUrl, !urlString.isEmpty,
                  let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                case .failure:
                    defaultAvatar(size: size)
                default:
                    ProgressView()
                        .frame(width: size, height: size)
                }
            }
        } else {
            defaultAvatar(size: size)
        }
    }
    
    private func defaultAvatar(size: CGFloat) -> some View {
        Image(systemName: "person.circle.fill")
            .font(.system(size: size))
            .foregroundStyle(.blue)
    }
    
    // MARK: - Computed Properties
    
    private var displayName: String {
        if let name = profile?.displayName, !name.isEmpty {
            return name
        }
        return "Account"
    }
    
    private var displayEmail: String {
        if let email = profile?.email, !email.isEmpty {
            return email
        }
        return authEmail
    }
    
    private var countryFlag: String {
        let iso = profile?.countryIso ?? "US"
        return CountryCodes.find(isoCode: iso)?.flag ?? "🇺🇸"
    }
    
    private var selectedCountry: CountryCode {
        CountryCodes.find(isoCode: editCountryIso) ?? CountryCodes.all[0]
    }
    
    // MARK: - Editing Actions
    
    private func beginEditing() {
        editName = profile?.displayName ?? ""
        editEmail = profile?.email ?? ""
        editPhone = profile?.phone ?? ""
        editCountryIso = profile?.countryIso ?? "US"
        editAvatarEmoji = profile?.avatarEmoji
        editAvatarUrl = profile?.avatarUrl
        avatarImage = nil
        selectedPhoto = nil
        statusMessage = nil
        withAnimation(.easeInOut(duration: 0.25)) {
            isEditing = true
        }
    }
    
    private func cancelEditing() {
        avatarImage = nil
        selectedPhoto = nil
        statusMessage = nil
        withAnimation(.easeInOut(duration: 0.25)) {
            isEditing = false
        }
    }
    
    // MARK: - Photo Loading
    
    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        _Concurrency.Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                avatarImage = image
                editAvatarEmoji = nil
                editAvatarUrl = nil
            }
        }
    }
    
    // MARK: - Profile CRUD
    
    private func loadProfile() {
        _Concurrency.Task {
            do {
                let session = try await SupabaseConfig.client.auth.session
                let uid = session.user.id
                userId = uid
                authEmail = session.user.email ?? "—"
                
                let profiles: [UserProfile] = try await SupabaseConfig.client
                    .from("user_profiles")
                    .select()
                    .eq("id", value: uid.uuidString)
                    .execute()
                    .value
                
                if let existing = profiles.first {
                    profile = existing
                } else {
                    // Auto-create profile on first load
                    var fullName: String?
                    if let metadata = session.user.userMetadata["full_name"],
                       case let .string(name) = metadata,
                       !name.isEmpty {
                        fullName = name
                    }
                    
                    let newProfile = UserProfileUpsert(
                        id: uid,
                        displayName: fullName,
                        email: session.user.email,
                        phone: nil,
                        countryIso: "US",
                        avatarUrl: nil,
                        avatarEmoji: nil,
                        updatedAt: Date()
                    )
                    
                    try await SupabaseConfig.client
                        .from("user_profiles")
                        .upsert(newProfile)
                        .execute()
                    
                    profile = UserProfile(
                        id: uid,
                        displayName: fullName,
                        email: session.user.email,
                        phone: nil,
                        countryIso: "US",
                        avatarUrl: nil,
                        avatarEmoji: nil,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                }
            } catch {
                authEmail = "—"
            }
        }
    }
    
    private func saveProfile() {
        guard let userId else { return }
        
        // Validate email if provided
        let trimmedEmail = editEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedEmail.isEmpty && !trimmedEmail.isValidEmail {
            statusMessage = "Error: Invalid email format"
            return
        }
        
        isSaving = true
        statusMessage = nil
        
        _Concurrency.Task {
            do {
                var finalAvatarUrl = editAvatarUrl
                
                // Upload photo if user picked one
                if let image = avatarImage,
                   let imageData = image.jpegData(compressionQuality: 0.7) {
                    let filePath = "\(userId.uuidString)/avatar.jpg"
                    
                    // Upload to Supabase Storage
                    try await SupabaseConfig.client.storage
                        .from("avatars")
                        .upload(
                            filePath,
                            data: imageData,
                            options: FileOptions(
                                cacheControl: "3600",
                                contentType: "image/jpeg",
                                upsert: true
                            )
                        )
                    
                    // Get public URL
                    let publicUrl = try SupabaseConfig.client.storage
                        .from("avatars")
                        .getPublicURL(path: filePath)
                    
                    finalAvatarUrl = publicUrl.absoluteString
                }
                
                let update = UserProfileUpsert(
                    id: userId,
                    displayName: editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editName.trimmingCharacters(in: .whitespacesAndNewlines),
                    email: trimmedEmail.isEmpty ? nil : trimmedEmail,
                    phone: editPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editPhone.trimmingCharacters(in: .whitespacesAndNewlines),
                    countryIso: editCountryIso,
                    avatarUrl: editAvatarEmoji != nil ? nil : finalAvatarUrl,
                    avatarEmoji: editAvatarEmoji,
                    updatedAt: Date()
                )
                
                try await SupabaseConfig.client
                    .from("user_profiles")
                    .upsert(update)
                    .execute()
                
                // Also update auth metadata if name changed
                let trimmedName = editName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedName.isEmpty {
                    try await SupabaseConfig.client.auth.update(
                        user: UserAttributes(data: ["full_name": .string(trimmedName)])
                    )
                }
                
                // Reload profile
                isSaving = false
                statusMessage = "Saved!"
                avatarImage = nil
                selectedPhoto = nil
                
                // Refresh from DB
                let profiles: [UserProfile] = try await SupabaseConfig.client
                    .from("user_profiles")
                    .select()
                    .eq("id", value: userId.uuidString)
                    .execute()
                    .value
                
                if let updated = profiles.first {
                    profile = updated
                }
                
                // Collapse after brief delay
                try? await _Concurrency.Task.sleep(for: .seconds(0.8))
                withAnimation(.easeInOut(duration: 0.25)) {
                    isEditing = false
                    statusMessage = nil
                }
            } catch {
                isSaving = false
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    private func loadContactCount() {
        _Concurrency.Task {
            do {
                let session = try await SupabaseConfig.client.auth.session
                let uid = session.user.id.uuidString
                let response: [ContactCountRow] = try await SupabaseConfig.client
                    .from("contacts")
                    .select()
                    .eq("user_id", value: uid)
                    .execute()
                    .value
                contactCount = response.count
            } catch {
                contactCount = 0
            }
        }
    }
}

// MARK: - Country Code Picker

struct CountryCodePickerView: View {
    @Binding var selectedIsoCode: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    private var filteredCountries: [CountryCode] {
        if searchText.isEmpty {
            return CountryCodes.all
        }
        return CountryCodes.all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.dialCode.contains(searchText) ||
            $0.isoCode.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var normalizedSelectedIso: String {
        let trimmed = selectedIsoCode.trimmingCharacters(in: .whitespaces).uppercased()
        if trimmed.hasPrefix("+") {
            return "US"
        }
        return trimmed
    }
    
    var body: some View {
        NavigationStack {
            List(filteredCountries) { country in
                Button {
                    selectedIsoCode = country.isoCode
                    dismiss()
                } label: {
                    HStack {
                        Text(country.flag)
                            .font(.title2)
                        Text(country.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(country.dialCode)
                            .foregroundStyle(.secondary)
                        if country.isoCode.uppercased().trimmingCharacters(in: .whitespaces) == normalizedSelectedIso {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search countries")
            .navigationTitle("Country Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct ContactCountRow: Codable {
    let id: UUID
}

#Preview {
    NavigationStack {
        ProfileView(authManager: AuthManager())
            .modelContainer(for: [Task.self, GroceryStore.self], inMemory: true)
    }
}
