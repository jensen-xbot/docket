import SwiftUI
import MessageUI

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
