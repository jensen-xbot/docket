import SwiftUI

struct SharedAvatarView: View {
    let currentUserProfile: UserProfile?
    let sharerProfile: UserProfile?
    /// For owner-side: profiles of people this task is shared with
    let recipientProfiles: [UserProfile]?
    let size: CGFloat
    
    @State private var showLabel = false
    
    /// Recipient view: shows current user + sharer overlap
    init(currentUserProfile: UserProfile?, sharerProfile: UserProfile?, size: CGFloat = 24) {
        self.currentUserProfile = currentUserProfile
        self.sharerProfile = sharerProfile
        self.recipientProfiles = nil
        self.size = size
    }
    
    /// Owner view: shows current user behind + recipients on top
    init(currentUserProfile: UserProfile?, recipientProfiles: [UserProfile], size: CGFloat = 24) {
        self.currentUserProfile = currentUserProfile
        self.sharerProfile = nil
        self.recipientProfiles = recipientProfiles
        self.size = size
    }
    
    /// Label text shown on tap
    private var labelText: String {
        if let recipients = recipientProfiles, !recipients.isEmpty {
            let names = recipients.prefix(3).compactMap { $0.displayName ?? $0.email }
            return "You shared with \(names.joined(separator: ", "))"
        } else if let sharer = sharerProfile {
            let name = sharer.displayName ?? sharer.email ?? "Someone"
            return "\(name) shared with you"
        }
        return "Shared"
    }
    
    var body: some View {
        // Tap target wraps the avatar stack; sized to 44pt minimum for accessibility
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { showLabel = true }
            _Concurrency.Task { @MainActor in
                try? await _Concurrency.Task.sleep(for: .seconds(2))
                withAnimation(.easeInOut(duration: 0.3)) { showLabel = false }
            }
        } label: {
            avatarStack
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .overlay(alignment: .top) {
            if showLabel {
                Text(labelText)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    .offset(y: -28)
                    .fixedSize()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .allowsHitTesting(false)
            }
        }
        .zIndex(showLabel ? 999 : 0)
    }
    
    @ViewBuilder
    private var avatarStack: some View {
        if let recipients = recipientProfiles, !recipients.isEmpty {
            // Owner-side: "me" behind (left), recipient(s) on top (right)
            HStack(spacing: -(size * 0.4)) {
                avatarView(profile: currentUserProfile, isCurrentUser: true)
                ForEach(recipients.prefix(2), id: \.id) { profile in
                    avatarView(profile: profile, isCurrentUser: false)
                }
            }
        } else {
            // Recipient-side: sharer behind (left), "me" on top (right)
            HStack(spacing: -(size * 0.4)) {
                avatarView(profile: sharerProfile, isCurrentUser: false)
                avatarView(profile: currentUserProfile, isCurrentUser: true)
            }
        }
    }
    
    @ViewBuilder
    private func avatarView(profile: UserProfile?, isCurrentUser: Bool) -> some View {
        if let emoji = profile?.avatarEmoji, !emoji.isEmpty {
            Text(emoji)
                .font(.system(size: size * 0.6))
                .frame(width: size, height: size)
                .background(Color(.secondarySystemFill))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color(.systemBackground), lineWidth: 1.5)
                )
        } else if let urlString = profile?.avatarUrl, !urlString.isEmpty,
                  let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 1.5)
                        )
                case .failure:
                    defaultAvatar
                default:
                    ProgressView()
                        .frame(width: size, height: size)
                }
            }
        } else {
            defaultAvatar
        }
    }
    
    private var defaultAvatar: some View {
        Image(systemName: "person.circle.fill")
            .font(.system(size: size))
            .foregroundStyle(.blue)
            .overlay(
                Circle()
                    .stroke(Color(.systemBackground), lineWidth: 1.5)
            )
    }
}

#Preview {
    HStack {
        SharedAvatarView(
            currentUserProfile: UserProfile(
                id: UUID(),
                displayName: "You",
                email: "you@example.com",
                phone: nil,
                countryIso: "US",
                avatarUrl: nil,
                avatarEmoji: "👤",
                createdAt: Date(),
                updatedAt: Date()
            ),
            sharerProfile: UserProfile(
                id: UUID(),
                displayName: "Jon",
                email: "jon@example.com",
                phone: nil,
                countryIso: "US",
                avatarUrl: nil,
                avatarEmoji: "👨",
                createdAt: Date(),
                updatedAt: Date()
            )
        )
        
        Spacer()
    }
    .padding()
}
