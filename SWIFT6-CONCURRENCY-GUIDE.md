# Swift 6 Strict Concurrency + @MainActor + @Observable: Survival Guide

*Lessons learned from Docket's voice-to-task feature (Feb 2026)*

---

## The Problem

Swift 6 with `SWIFT_STRICT_CONCURRENCY = complete` enforces **runtime dispatch queue assertions** for actor isolation. The crash signature is always:

```
libdispatch.dylib`_dispatch_assert_queue_fail
BUG IN CLIENT OF LIBDISPATCH: Assertion failed:
  Block was expected to execute on queue [com.apple.main-thread]
```

The stack trace typically includes:
```
_dispatch_assert_queue_fail       libdispatch.dylib
dispatch_assert_queue             libdispatch.dylib
_swift_task_checkIsolatedSwift    libswift_Concurrency.dylib
swift_task_isCurrentExecutorWithFlagsImpl
<your closure>                    YourApp
```

**This happens because:** When you define a closure inside a `@MainActor` method, Swift 6 marks that closure as `@MainActor`-isolated. If an Objective-C framework (AVFoundation, Speech, UserNotifications, etc.) calls that closure on a background thread, the runtime assertion fails and the app crashes.

**Swift 5 silently allows these data races. Swift 6 crashes.**

---

## Build Settings That Trigger This

```
SWIFT_STRICT_CONCURRENCY = complete
SWIFT_VERSION = 6.0
```

If you use these settings (recommended for new projects), you MUST follow every rule below.

---

## The Rules

### Rule 1: Never use `DispatchQueue.main.async` in `@MainActor` classes

`DispatchQueue.main.async` runs code on the main thread, but Swift 6 doesn't recognize it as `@MainActor` context. The `@Observable` property accessors include dispatch assertions that can fail.

```swift
// BAD — crashes in Swift 6
monitor.pathUpdateHandler = { [weak self] path in
    DispatchQueue.main.async {
        self?.isConnected = path.status == .satisfied  // @Observable assertion fails
    }
}

// GOOD — proper @MainActor hop
monitor.pathUpdateHandler = { [weak self] path in
    let isSatisfied = path.status == .satisfied
    _Concurrency.Task { @MainActor [weak self] in
        self?.isConnected = isSatisfied
    }
}
```

**Note:** If your project has a SwiftData `Task` model (or any type named `Task`), you must use `_Concurrency.Task` to reference Swift's built-in Task.

### Rule 2: Closures defined in `@MainActor` methods inherit `@MainActor` isolation

This is the most dangerous rule. Even if a closure doesn't reference `self`, Swift 6 marks it `@MainActor` because it was *defined* inside a `@MainActor` method. When an ObjC API calls it on a background thread, crash.

```swift
@MainActor class AudioManager {
    func startRecording() {
        // BAD — this closure IS @MainActor because startRecording() is
        inputNode.installTap(onBus: 0, ...) { buffer, _ in
            request.append(buffer)  // Runs on audio IO thread → CRASH
        }
    }
}
```

**Fix: Extract into a `nonisolated static` method:**

```swift
@MainActor class AudioManager {
    func startRecording() {
        // Pass values out, call nonisolated helper
        Self.installAudioTap(on: inputNode, format: format, request: request)
    }
    
    // GOOD — nonisolated static, so the closure is NOT @MainActor
    private nonisolated static func installAudioTap(
        on inputNode: AVAudioInputNode,
        format: AVAudioFormat,
        request: SFSpeechAudioBufferRecognitionRequest
    ) {
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)  // Runs on audio IO thread — fine!
        }
    }
}
```

### Rule 3: Use async APIs instead of completion handlers

Completion handlers from ObjC APIs run on arbitrary threads. In a `@MainActor` method, Swift 6 marks the closure `@MainActor`, and the ObjC framework calls it on a background thread. Crash.

```swift
// BAD — completion handler runs on background thread
func registerForPush() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, error in
        // Swift 6 thinks this closure is @MainActor → CRASH
        if granted {
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}

// GOOD — async version stays on @MainActor
func registerForPush() {
    _Concurrency.Task {
        let granted = try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert])
        if granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}
```

**Common APIs with async alternatives:**
| Closure-based (BAD) | Async (GOOD) |
|---|---|
| `UNUserNotificationCenter.requestAuthorization(_:completionHandler:)` | `try await UNUserNotificationCenter.requestAuthorization(options:)` |
| `AVAudioApplication.requestRecordPermission(_:)` | `await AVAudioApplication.requestRecordPermission()` |
| `PHPhotoLibrary.requestAuthorization(_:)` | `await PHPhotoLibrary.requestAuthorization(for:)` |

### Rule 4: ObjC delegate methods must be `nonisolated`

Delegate methods from ObjC frameworks (AVSpeechSynthesizerDelegate, UNUserNotificationCenterDelegate, etc.) are called on arbitrary threads. If your class is `@MainActor`, the delegate methods inherit that isolation and crash when called off-main.

```swift
@MainActor class TTSManager: NSObject, AVSpeechSynthesizerDelegate {
    // GOOD — nonisolated, then hop to @MainActor inside
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        _Concurrency.Task { @MainActor in
            isSpeaking = false
            completionHandler?()
            completionHandler = nil
        }
    }
}
```

### Rule 5: Don't use `#selector` / `@objc` for notifications

`@objc` methods in `@MainActor` classes are still `@MainActor`-isolated. `NotificationCenter` calls the selector on whatever thread the notification was posted from. If that's a background thread, crash.

```swift
// BAD — @objc method is @MainActor, notification fires on background thread
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleInterruption),
    name: AVAudioSession.interruptionNotification,
    object: nil
)

@objc func handleInterruption(_ notification: Notification) {
    // CRASH if notification posted on background thread
}

// GOOD — block-based observer with explicit .main queue
interruptionObserver = NotificationCenter.default.addObserver(
    forName: AVAudioSession.interruptionNotification,
    object: audioSession,
    queue: .main  // <-- ensures handler runs on main thread
) { [weak self] notification in
    _Concurrency.Task { @MainActor [weak self] in
        // Safe to access @MainActor state here
    }
}
```

### Rule 6: Don't send non-Sendable types across actor boundaries

When hopping from a background closure to `@MainActor`, only pass `Sendable` values. ObjC types like `SFSpeechRecognitionResult` are not `Sendable`.

```swift
// BAD — sending non-Sendable SFSpeechRecognitionResult across actor boundary
recognizer.recognitionTask(with: request) { result, error in
    _Concurrency.Task { @MainActor in
        self.text = result.bestTranscription.formattedString  // Compiler error
    }
}

// GOOD — extract Sendable values before crossing boundary
recognizer.recognitionTask(with: request) { result, error in
    let transcription = result?.bestTranscription.formattedString  // String is Sendable
    let isFinal = result?.isFinal ?? false                         // Bool is Sendable
    
    _Concurrency.Task { @MainActor in
        if let transcription {
            self.text = transcription  // Fine — String is Sendable
        }
    }
}
```

### Rule 7: Don't mix `@Observable` with `@UIApplicationDelegateAdaptor`

`@Observable` generates property accessors with `@MainActor` dispatch assertions. `@UIApplicationDelegateAdaptor` may access the delegate from non-main contexts internally. Together they crash.

```swift
// BAD — @Observable + @UIApplicationDelegateAdaptor = crash
@MainActor
@Observable  // ← Remove this
class AppDelegate: NSObject, UIApplicationDelegate { ... }

// GOOD — no @Observable on the app delegate
@MainActor
class AppDelegate: NSObject, UIApplicationDelegate {
    var pendingNavigation: UUID?  // Use NotificationCenter to communicate instead
}
```

### Rule 8: `deinit` is `nonisolated` — can't touch `@MainActor` properties

In Swift 6, `deinit` is always `nonisolated`. You cannot access `@MainActor`-isolated stored properties.

```swift
// BAD — accessing @MainActor property from nonisolated deinit
deinit {
    if let observer = interruptionObserver {  // Compiler error
        NotificationCenter.default.removeObserver(observer)
    }
}

// GOOD — rely on [weak self] in closures; skip cleanup
// The observer closure captures [weak self], so when self is
// deallocated, the closure safely becomes a no-op.
deinit {}
```

**Note:** `nonisolated(unsafe)` does NOT work on `@Observable` stored properties — the macro expands them into computed properties with observation tracking, and `nonisolated(unsafe)` has no effect.

### Rule 9: Make `_Concurrency.Task` blocks explicitly `@MainActor in`

When creating Tasks inside `@MainActor` methods, be explicit. While Tasks should inherit the actor context, being explicit avoids subtle issues with SDK callbacks:

```swift
// OK but implicit
_Concurrency.Task {
    self.isAuthenticated = true
}

// BETTER — explicit and clear
_Concurrency.Task { @MainActor in
    self.isAuthenticated = true
}
```

---

## Pattern Catalog

### NWPathMonitor (Network connectivity)

```swift
@MainActor @Observable
class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    var isConnected = true  // Default true; monitor fires immediately

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isSatisfied = path.status == .satisfied
            _Concurrency.Task { @MainActor [weak self] in
                guard let self else { return }
                self.isConnected = isSatisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
```

### AVAudioEngine + SFSpeechRecognizer

```swift
@Observable @MainActor
class SpeechManager: NSObject {
    func startRecording() async {
        let request = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest = request
        
        // Nonisolated helpers — closures run on background threads
        Self.installAudioTap(on: audioEngine.inputNode, format: format, request: request)
        recognitionTask = Self.beginRecognition(recognizer: recognizer, request: request, manager: self)
    }

    // Static + nonisolated = closure is NOT @MainActor
    private nonisolated static func installAudioTap(
        on node: AVAudioInputNode, format: AVAudioFormat,
        request: SFSpeechAudioBufferRecognitionRequest
    ) {
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }

    private nonisolated static func beginRecognition(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        manager: SpeechManager
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { [weak manager] result, error in
            // Extract Sendable values BEFORE crossing actor boundary
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            _Concurrency.Task { @MainActor [weak manager] in
                guard let manager else { return }
                if let text { manager.transcribedText = text }
                if isFinal { await manager.stopRecording() }
            }
        }
    }
}
```

### AVSpeechSynthesizer (TTS)

```swift
@Observable @MainActor
class TTSManager: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    var isSpeaking = false
    private var completionHandler: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // Delegate methods: always nonisolated, hop to @MainActor inside
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        _Concurrency.Task { @MainActor in
            isSpeaking = false
            let handler = completionHandler
            completionHandler = nil
            handler?()
        }
    }
}
```

### Push Notifications

```swift
// NO @Observable — conflicts with @UIApplicationDelegateAdaptor
@MainActor
class PushNotificationManager: NSObject, UNUserNotificationCenterDelegate, UIApplicationDelegate {
    
    // Use async requestAuthorization — not the completion handler version
    func register() {
        _Concurrency.Task {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // Delegate methods: nonisolated
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
```

### Supabase Auth State Changes

```swift
@MainActor @Observable
class AuthManager {
    private func observeAuthChanges() {
        // Explicit @MainActor — ensures Supabase SDK callbacks
        // resume on the correct actor
        _Concurrency.Task { @MainActor in
            for await (event, session) in supabase.auth.authStateChanges {
                switch event {
                case .signedIn:  self.isAuthenticated = true
                case .signedOut: self.isAuthenticated = false
                default: break
                }
            }
        }
    }
}
```

---

## Debugging Checklist

When you see `_dispatch_assert_queue_fail`:

1. **Look at the crashing thread** — is it the main thread or a background queue?
2. **Read the stack trace** — find your code (frame 5+). It will point to the exact closure.
3. **Check if the closure is inside a `@MainActor` method** — if yes, Swift 6 marks it `@MainActor`.
4. **Check what calls the closure** — if it's an ObjC API (AVFoundation, Speech, UIKit), it runs on a background thread.
5. **Apply the fix:**
   - Completion handler → use async version of the API
   - Audio/recognition callback → extract to `nonisolated static` helper
   - Delegate method → mark `nonisolated`, hop to `@MainActor` inside
   - `DispatchQueue.main.async` → replace with `Task { @MainActor in }`
   - NotificationCenter `#selector` → use block-based with `queue: .main`

---

## Quick Reference: What Can Crash

| Pattern | Why It Crashes | Fix |
|---|---|---|
| Closure in `@MainActor` method passed to ObjC API | Closure inherits `@MainActor`, ObjC calls on background | `nonisolated static` helper |
| `DispatchQueue.main.async` in `@MainActor @Observable` class | Not recognized as `@MainActor` context | `Task { @MainActor in }` |
| `@objc func` handling notification | `@MainActor` method called from background thread | Block-based observer with `queue: .main` |
| `@Observable` + `@UIApplicationDelegateAdaptor` | Internal SwiftUI access triggers `@MainActor` assertion | Remove `@Observable` |
| Sending non-`Sendable` ObjC type to `@MainActor` Task | Data race across actor boundary | Extract `String`/`Bool` values first |
| `deinit` accessing `@MainActor` property | `deinit` is `nonisolated` in Swift 6 | Use `[weak self]` in closures; skip cleanup |
| `requestAuthorization(completionHandler:)` | Completion runs on background thread | `try await requestAuthorization(options:)` |

---

## Supabase Edge Function + Swift SDK Gotchas

### Rule 10: Edge Functions gateway JWT verification may reject valid Swift SDK tokens

The Supabase Edge Functions gateway (`verify_jwt: true`) performs its own JWT validation before the function code runs. The Swift SDK's JWT format can be rejected with `{"code":401,"message":"Invalid JWT"}` even when `supabase.auth.session` returns a valid, non-expired token.

**Diagnosis:** If your Edge Function logs show 401 with very fast execution (< 200ms), and the iOS client confirms a valid session, the gateway is rejecting the token — not your function code.

```swift
// This succeeds — session is valid
let session = try await supabase.auth.session
print("Token expires: \(session.expiresAt)")  // Future date — not expired

// But this fails with 401 "Invalid JWT"
let result: MyResponse = try await supabase.functions.invoke("my-function", ...)
```

**Fix:** Deploy with `--no-verify-jwt` and validate auth inside the function:

```bash
supabase functions deploy my-function --no-verify-jwt --project-ref <ref>
```

```typescript
// Function validates auth itself via getUser()
const { data: { user }, error } = await supabase.auth.getUser();
if (error || !user) {
  return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
}
```

This is safe because `getUser()` validates the JWT against the auth server. The gateway check is redundant.

### Rule 11: Always pass explicit Authorization header with `functions.invoke()`

Even though the SDK should handle this automatically, explicitly passing the auth header prevents edge cases where the SDK's internal header management doesn't match:

```swift
let session = try await supabase.auth.session
let response: MyResponse = try await supabase.functions.invoke(
    "my-function",
    options: FunctionInvokeOptions(
        headers: ["Authorization": "Bearer \(session.accessToken)"],
        body: requestBody
    )
)
```

### Rule 12: Handle `FunctionsError` separately for better diagnostics

The Supabase SDK throws `FunctionsError.httpError` for non-2xx responses and `FunctionsError.relayError` for boot failures. Catch these specifically:

```swift
do {
    let response: MyType = try await supabase.functions.invoke("my-function", ...)
} catch let error as FunctionsError {
    switch error {
    case .httpError(let code, let data):
        let body = String(data: data, encoding: .utf8) ?? ""
        print("HTTP \(code): \(body)")  // Shows exact error from function
    case .relayError:
        print("Edge Function failed to boot")
    }
} catch {
    print("Other error: \(error)")
}
```

---

## Audio Session Management Gotchas

### Rule 13: AVAudioEngine restart after TTS produces empty buffers

When the mic restarts after TTS finishes speaking (via `AVSpeechSynthesizerDelegate.didFinish`), the audio engine may produce empty buffers initially:

```
AVAudioBuffer.mm:281   mBuffers[0].mDataByteSize (0) should be non-zero
IPCAUClient.cpp:139   IPCAUClient: can't connect to server (-66748)
```

These are **warnings, not crashes**. The audio engine recovers within ~100ms. Don't try to suppress them — they're internal AVFoundation logs that appear during audio session category switching between playback (TTS) and recording (mic).

### Rule 14: Silence detection needs adaptive timeouts

A fixed silence timeout doesn't work for conversational voice:
- Too short (< 2s): Cuts off mid-sentence while user is thinking
- Too long (> 5s): Feels unresponsive after user finishes speaking

**Adaptive approach:**
```swift
let wordCount = transcribedText.split(separator: " ").count
let timeout = wordCount >= 3 ? 3.5 : 2.5  // Longer for ongoing dictation
```

- **1-2 words** ("yes", "add it"): 2.5s — quick confirmations
- **3+ words** (full sentence): 3.5s — give time to pause mid-thought
- Timer resets on every new transcription result

### Rule 15: SwiftData `Task` name conflicts with `_Concurrency.Task`

If your SwiftData model is named `Task`, Swift's built-in `Task` (for async concurrency) becomes ambiguous. Always use the fully qualified name:

```swift
// BAD — ambiguous, resolves to your SwiftData Task model
Task { @MainActor in ... }

// GOOD — explicitly references Swift concurrency Task
_Concurrency.Task { @MainActor in ... }
```

This affects every file that uses both your model and Swift concurrency.

---

*This guide was battle-tested on Docket (iOS 17+, Swift 6.0, Xcode 16+, Supabase Swift SDK). Every crash and issue in this document was a real problem that was debugged and fixed. Last updated: Feb 8, 2026.*
