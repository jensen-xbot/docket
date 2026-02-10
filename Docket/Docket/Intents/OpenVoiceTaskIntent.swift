@preconcurrency import AppIntents
import SwiftUI

/// AppIntent to open VoiceRecordingView via Siri or Shortcuts.
/// User can say "Hey Siri, add task in Docket" after adding the shortcut.
struct OpenVoiceTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Task with Voice"
    static let description = IntentDescription("Opens Docket to add a task using your voice.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "openVoiceRecordingFromShortcut")
        return .result()
    }
}

/// Exposes the shortcut to Siri and the Shortcuts app.
struct DocketShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenVoiceTaskIntent(),
            phrases: [
                "Add task in \(.applicationName)",
                "Add task with \(.applicationName)",
                "Open voice task in \(.applicationName)",
            ],
            shortTitle: "Add Task with Voice",
            systemImageName: "mic.fill"
        )
    }
}
