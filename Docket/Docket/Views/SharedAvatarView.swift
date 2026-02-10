import SwiftUI

struct SharedAvatarView: View {
    let currentUserProfile: UserProfile?
    let sharerProfile: UserProfile?
    /// For owner-side: profiles of people this task is shared with
    let recipientProfiles: [UserProfile]?
    let size: CGFloat
    
    /// Recipient view: shows current user + sharer overlap
    init(currentUserProfile: UserProfile?, sharerProfile: UserProfile?, size: CGFloat = 24) {
        self.currentUserProfile = currentUserProfile
        self.sharerProfile = sharerProfile
        self.recipientProfiles = nil
        self.size = size
    }
    
    /// Owner view: shows recipients this task is shared with
    init(recipientProfiles: [UserProfile], size: CGFloat = 24) {
        self.currentUserProfile = nil
        self.sharerProfile = nil
        self.recipientProfiles = recipientProfiles
        self.size = size
    }
    
    var body: some View {
        if let recipients = recipientProfiles, !recipients.isEmpty {
            // Owner-side: stack of recipient avatars
            HStack(spacing: -(size * 0.4)) {
                ForEach(recipients.prefix(3), id: \.id) { profile in
                    avatarView(profile: profile, isCurrentUser: false)
                }
            }
        } else {
            // Recipient-side: current user + sharer overlap
            HStack(spacing: -(size * 0.4)) {
                avatarView(profile: currentUserProfile, isCurrentUser: true)
                avatarView(profile: sharerProfile, isCurrentUser: false)
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
