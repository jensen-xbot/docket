import SwiftUI

/// Minimalistic contact card for voice share confirmation.
/// Avatar (left), Name/phone/email (centered), 3 share method buttons (bottom).
struct ShareConfirmationCard: View {
    let contact: ContactRecord
    let taskTitle: String
    let onDocket: () -> Void
    let onEmail: () -> Void
    let onText: () -> Void

    private var displayName: String {
        contact.contactName ?? contact.contactEmail
    }

    private var initials: String {
        let name = displayName
        let parts = name.split(separator: " ")
        if parts.count >= 2, let first = parts.first?.first, let last = parts.last?.first {
            return "\(first)\(last)".uppercased()
        }
        if let first = name.first {
            return String(first).uppercased()
        }
        return "?"
    }

    private var isDocketMember: Bool {
        contact.contactUserId != nil
    }

    private var hasPhone: Bool {
        guard let phone = contact.contactPhone else { return false }
        return !phone.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 16) {
            // Row 1: Avatar (left) | Name, phone, email (centered)
            HStack(spacing: 14) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 40, height: 40)
                    Text(initials)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let phone = contact.contactPhone, !phone.isEmpty {
                        Text(phone)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(contact.contactEmail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Row 2: 3 vertical buttons
            VStack(spacing: 8) {
                // Docket
                Button {
                    if isDocketMember { onDocket() }
                } label: {
                    HStack(spacing: 12) {
                        Image("DocketLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text(isDocketMember ? "Share via Docket" : "Not a Docket member")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        if isDocketMember {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(isDocketMember ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .foregroundStyle(isDocketMember ? .blue : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(!isDocketMember)

                // Email
                Button { onEmail() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .frame(width: 20)
                            .foregroundStyle(.blue)
                        Text("Email")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text(contact.contactEmail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                // Text
                Button {
                    if hasPhone { onText() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "message.fill")
                            .frame(width: 20)
                            .foregroundStyle(hasPhone ? .green : .secondary)
                        Text(hasPhone ? "Text" : "No phone number")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        if let phone = contact.contactPhone, !phone.isEmpty {
                            Text(phone)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(!hasPhone)
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    ShareConfirmationCard(
        contact: ContactRecord(
            id: UUID(),
            contactEmail: "tarryn@example.com",
            contactName: "Tarryn",
            contactPhone: "+1234567890",
            contactUserId: UUID()
        ),
        taskTitle: "Call Mom",
        onDocket: { },
        onEmail: { },
        onText: { }
    )
    .padding()
}
