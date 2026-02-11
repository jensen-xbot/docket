import Foundation

/// Classifies user voice utterances into deterministic control intents.
/// All logic is on-device — no network calls. Used by VoiceRecordingView to decide
/// whether to confirm, reject, dismiss, acknowledge gratitude, or send to the AI parser.
///
/// See VOICE-INTENT-RULES.md for full documentation.
enum VoiceIntent {
    case confirm
    case reject
    case dismiss
    case gratitude
    case taskRequest
}

struct IntentClassifier {
    
    struct Context {
        let isInClosingFlow: Bool
        let hasPendingTasks: Bool
    }
    
    private static let closingFlowWordThreshold = 5
    
    func classify(_ text: String, context: Context) -> VoiceIntent {
        // 1. Pending confirmation: user must confirm or reject parsed tasks
        if context.hasPendingTasks {
            if isConfirmation(text) { return .confirm }
            if isRejection(text) { return .reject }
            return .taskRequest
        }
        
        // 2. Closing flow: short replies = dismiss, long = new task
        if context.isInClosingFlow {
            let wordCount = text.split(separator: " ").count
            if isDismissal(text) || wordCount <= Self.closingFlowWordThreshold {
                return .dismiss
            }
            return .taskRequest
        }
        
        // 3. Explicit dismissal (e.g. "bye" unprompted)
        if isDismissal(text) { return .dismiss }
        
        // 4. Gratitude → warm acknowledgment flow
        if isGratitude(text) { return .gratitude }
        
        return .taskRequest
    }
    
    private func matchesPhrase(_ text: String, phrases: [String]) -> Bool {
        let lowercased = text.lowercased()
        for phrase in phrases {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: phrase))\\b"
            if lowercased.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }
    
    private func isConfirmation(_ text: String) -> Bool {
        let confirmations = [
            "yes", "yeah", "yep", "sure", "ok", "okay",
            "add it", "add them", "add all",
            "confirm", "sounds good", "that's right", "correct"
        ]
        return matchesPhrase(text, phrases: confirmations)
    }
    
    private func isRejection(_ text: String) -> Bool {
        let rejections = [
            "no", "nope", "cancel", "never mind", "forget it", "don't", "stop"
        ]
        return matchesPhrase(text, phrases: rejections)
    }
    
    private func isDismissal(_ text: String) -> Bool {
        let dismissals = [
            "no", "nope", "no thanks",
            "that's all", "that's it",
            "i'm done", "i'm good",
            "nothing", "all done", "all good",
            "bye", "goodbye", "see you", "talk to you later"
        ]
        return matchesPhrase(text, phrases: dismissals)
    }
    
    private func isGratitude(_ text: String) -> Bool {
        let gratitude = [
            "thanks", "thank you",
            "thanks a lot", "thank you very much",
            "appreciate it", "much appreciated"
        ]
        return matchesPhrase(text, phrases: gratitude)
    }
}
