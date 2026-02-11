import SwiftUI
import SwiftData
import _Concurrency
import MessageUI

#if DEBUG
private enum VoiceTrace {
    static func trace(_ event: String) {
        let t = String(format: "%.3f", Date().timeIntervalSince1970)
        print("[VoiceTrace][\(t)] \(event)")
    }
}
#endif

enum VoiceRecordingState {
    case idle
    case listening
    case processing
    case speaking
    case complete
}

struct VoiceRecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncEngine.self) private var syncEngine
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Query(filter: #Predicate<Task> { !$0.isCompleted }, sort: \Task.createdAt, order: .reverse) private var activeTasks: [Task]
    @Query(sort: \GroceryStore.name) private var groceryStores: [GroceryStore]
    @State private var speechManager = SpeechRecognitionManager()
    @State private var ttsManager = TTSManager()
    @State private var parser = VoiceTaskParser()
    @State private var state: VoiceRecordingState = .idle
    @State private var messages: [ConversationMessage] = []
    @State private var parsedTasks: [ParsedTask] = []
    @State private var lastSavedTasks: [Task] = [] // Track recently saved tasks for corrections
    @State private var showingConfirmation = false
    @State private var errorMessage: String?
    @State private var conversationTimeoutTask: _Concurrency.Task<Void, Never>?
    @State private var isProcessingUtterance = false
    @State private var isInClosingFlow = false // true after "Anything else?" or "Will this be all?"
    @AppStorage("useWhisperTranscription") private var useWhisperTranscription = false
    @AppStorage("progressTrackingDefault") private var progressTrackingDefault = false
    private let conversationTimeoutSeconds: TimeInterval = 60
    private let appStoreURL = "https://apps.apple.com/app/docket/id0000000000"

    private enum ShareMethod { case docket, email, text }

    // Share confirmation flow
    struct PendingShareConfirmation {
        let tasks: [ParsedTask]
        let contact: ContactRecord
    }
    @State private var pendingShareConfirmation: PendingShareConfirmation?
    @State private var showMailCompose = false
    @State private var showTextCompose = false
    @State private var composeRecipient = ""
    @State private var composeSubject = ""
    @State private var composeBody = ""
    @State private var composeEmailForRecord = ""
    @State private var composeContactName = ""
    @State private var createdTaskForShare: Task?
    
    /// Combines committed messages with the live transcription into a single list.
    /// The live text gets the ID "msg-N" (where N = messages.count), which is the
    /// exact same ID it will have once committed to `messages`. This means SwiftUI
    /// treats the live bubble and the committed bubble as the SAME view — no
    /// disappear/reappear flash on transition.
    private var displayMessages: [DisplayMessage] {
        var result = messages.enumerated().map { index, msg in
            DisplayMessage(id: "msg-\(index)", message: msg)
        }
        // Show live transcript until commit: same ID as next message so SwiftUI
        // treats it as one view (no flicker). Keep showing during .processing too (we set
        // state = .processing at start of stopRecording to show "Thinking..." early);
        // transcribedText is only cleared after we append, so bubble stays until commit.
        if (state == .listening || state == .processing) && !speechManager.transcribedText.isEmpty {
            result.append(DisplayMessage(
                id: "msg-\(messages.count)",
                message: ConversationMessage(role: "user", content: speechManager.transcribedText)
            ))
        }
        return result
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    GeometryReader { geometry in
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                VStack(spacing: 12) {
                                    // Unified message list: committed messages + live transcription
                                    // share the same ID scheme so SwiftUI sees one continuous view
                                    // (no disappear/reappear flash on commit)
                                    ForEach(Array(displayMessages.enumerated()), id: \.element.id) { _, entry in
                                        MessageBubble(message: entry.message)
                                            .id(entry.id)
                                    }
                                    
                                    // Processing indicator with animation
                                    if state == .processing {
                                        AIThinkingIndicator(label: "Thinking...")
                                            .padding(.vertical, 4)
                                            .id("processing")
                                    }
                                    
                                    // TTS generating indicator (when OpenAI TTS is loading)
                                    if state == .speaking && ttsManager.isGeneratingTTS {
                                        AIThinkingIndicator(label: "Preparing voice...")
                                            .padding(.vertical, 4)
                                            .id("tts-loading")
                                    }

                                    // Share confirmation card (inline when pending)
                                    if let pending = pendingShareConfirmation {
                                        ShareConfirmationCard(
                                            contact: pending.contact,
                                            taskTitle: pending.tasks.first?.title ?? "Task",
                                            onDocket: { performShare(method: .docket) },
                                            onEmail: { performShare(method: .email) },
                                            onText: { performShare(method: .text) }
                                        )
                                        .padding(.horizontal)
                                        .id("share-confirmation")
                                    }

                                    // Scroll anchor
                                    Color.clear
                                        .frame(height: 1)
                                        .id("bottom")
                                }
                                .padding(.horizontal)
                                .padding(.top, 8)
                                .padding(.bottom, 8)
                            }
                            .frame(minHeight: geometry.size.height, alignment: .bottom)
                        }
                        .safeAreaPadding(.top, 0)
                        .onChange(of: messages.count) { _, _ in
                            // Deferred scroll so the new message layout commits
                            // WITHOUT animation, then we scroll smoothly
                            DispatchQueue.main.async {
                                scrollProxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                        .onChange(of: speechManager.transcribedText) { _, newValue in
                            if !newValue.isEmpty {
                                scrollProxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                        .onChange(of: state) { _, _ in
                            DispatchQueue.main.async {
                                scrollProxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                
                // Mic button
                VStack(spacing: 12) {
                    Button(action: toggleRecording) {
                        ZStack {
                            // Circle: red with breathing opacity when listening, blue when idle.
                            // phaseAnimator restarts reliably on every state change (unlike
                            // .animation(.repeatForever) which stalls after the first cycle).
                            Circle()
                                .fill(state == .listening ? Color.red : Color.blue)
                                .frame(width: 80, height: 80)
                                .phaseAnimator(
                                    [false, true],
                                    trigger: state
                                ) { content, phase in
                                    content.opacity(state == .listening && phase ? 0.8 : 1.0)
                                } animation: { _ in
                                    .easeInOut(duration: 1.2)
                                }
                            
                            // Mic icon with green audio-level fill
                            ZStack {
                                Image(systemName: "mic.fill")
                                    .font(.title)
                                    .foregroundStyle(.white)
                                
                                // Green level indicator — fills mic from bottom based on voice input
                                if state == .listening {
                                    Image(systemName: "mic.fill")
                                        .font(.title)
                                        .foregroundStyle(.green)
                                        .mask(
                                            VStack(spacing: 0) {
                                                Spacer(minLength: 0)
                                                Rectangle()
                                                    .frame(height: CGFloat(speechManager.audioLevel) * 30)
                                            }
                                            .frame(height: 30)
                                        )
                                        .animation(.easeOut(duration: 0.08), value: speechManager.audioLevel)
                                }
                            }
                        }
                    }
                    .disabled(state == .processing || state == .speaking)
                    
                    if state == .listening {
                        Text("Listening...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if state == .idle {
                        Text("Tap to start")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 32)
            }
            
            // Error overlay
            if let error = errorMessage {
                VStack {
                    Spacer()
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(8)
                        .padding()
                    Spacer()
                }
            }
            }
            .navigationTitle("Voice Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            _Concurrency.Task {
                let hasPermissions = await speechManager.requestPermissions()
                if !hasPermissions {
                    errorMessage = speechManager.errorMessage ?? "Microphone and speech recognition permissions are required."
                }
            }
            updateInterruptionResumeIntent()
        }
        .onChange(of: state) { _, _ in updateInterruptionResumeIntent() }
        .onChange(of: ttsManager.isSpeaking) { _, _ in updateInterruptionResumeIntent() }
        .onDisappear {
            speechManager.shouldResumeAfterInterruption = false
            cancelConversationTimeout()
            ttsManager.stop()
            _Concurrency.Task {
                await speechManager.stopRecording()
            }
        }
        .onChange(of: speechManager.isRecording) { oldValue, newValue in
            // Auto-process utterance when recording auto-stops due to silence detection
            // Only trigger if: was recording -> stopped, we're in listening state, and there's text
            if oldValue == true && newValue == false && state == .listening {
                let text = speechManager.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty && !isProcessingUtterance {
                    _Concurrency.Task {
                        await stopRecording()
                    }
                } else if text.isEmpty {
                    // Recording stopped with no speech detected — reset to idle
                    state = .idle
                }
            }
        }
        .sheet(isPresented: $showingConfirmation) {
            if !parsedTasks.isEmpty {
                TaskConfirmationView(tasks: $parsedTasks, onConfirm: saveTasks, onCancel: { dismiss() })
            }
        }
        .sheet(isPresented: $showMailCompose) {
            MailComposeView(
                recipient: composeRecipient,
                subject: composeSubject,
                body: composeBody
            ) { result in
                showMailCompose = false
                if case .sent = result, let task = createdTaskForShare {
                    recordShare(taskId: task.id, recipient: composeEmailForRecord)
                    let name = composeContactName.isEmpty ? composeEmailForRecord : composeContactName
                    ttsManager.speak("Shared with \(name) via email.") { }
                }
                createdTaskForShare = nil
                pendingShareConfirmation = nil
                askAnythingElse()
            }
        }
        .sheet(isPresented: $showTextCompose) {
            TextComposeView(
                recipient: composeRecipient,
                body: composeBody
            ) { result in
                showTextCompose = false
                if case .sent = result, let task = createdTaskForShare {
                    recordShare(taskId: task.id, recipient: composeEmailForRecord)
                    let name = composeContactName.isEmpty ? composeEmailForRecord : composeContactName
                    ttsManager.speak("Shared with \(name) via text.") { }
                }
                createdTaskForShare = nil
                pendingShareConfirmation = nil
                askAnythingElse()
            }
        }
    }
    
    private func toggleRecording() {
        _Concurrency.Task {
            if state == .listening {
                await stopRecording()
            } else {
                await startRecording()
            }
        }
    }
    
    private func startRecording() async {
        #if DEBUG
        VoiceTrace.trace("startRecording")
        #endif
        state = .listening
        errorMessage = nil
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        
        // Start conversation timeout
        startConversationTimeout()
        
        await speechManager.startRecording()
    }
    
    private func startConversationTimeout() {
        // Cancel existing timeout
        conversationTimeoutTask?.cancel()
        
        // Start new timeout
        conversationTimeoutTask = _Concurrency.Task {
            try? await _Concurrency.Task.sleep(nanoseconds: UInt64(conversationTimeoutSeconds * 1_000_000_000))
            
            // If still idle/listening after timeout, auto-dismiss silently
            if state == .idle || state == .listening {
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }
    
    private func cancelConversationTimeout() {
        conversationTimeoutTask?.cancel()
        conversationTimeoutTask = nil
    }
    
    /// View-driven intent for interruption recovery: resume listening after .ended only when we were in listening flow and not speaking.
    private func updateInterruptionResumeIntent() {
        let shouldResume = (state == .listening && !ttsManager.isSpeaking && !isProcessingUtterance)
        speechManager.shouldResumeAfterInterruption = shouldResume
    }
    
    private func stopRecording() async {
        guard !isProcessingUtterance else {
            #if DEBUG
            VoiceTrace.trace("stopRecording skipped (re-entry)")
            #endif
            return
        }
        isProcessingUtterance = true
        // Show "Thinking..." immediately when user stops (silence or tap) so perceived delay is minimal
        state = .processing
        #if DEBUG
        VoiceTrace.trace("stopRecording entry")
        #endif
        
        await speechManager.stopRecording()
        
        // Handle Whisper transcription if enabled
        var text = speechManager.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if useWhisperTranscription, let audioData = await speechManager.exportAudioAsWAV() {
            do {
                let whisperText = try await parser.transcribe(audioData: audioData)
                if !whisperText.isEmpty {
                    text = whisperText
                }
            } catch {
                // Fall back to Apple transcription on Whisper failure
                print("[VoiceRecordingView] Whisper failed, using Apple transcription: \(error)")
            }
        }
        
        // Check for empty transcription (clear "Thinking..." we set at stopRecording entry)
        guard !text.isEmpty else {
            state = .idle
            isProcessingUtterance = false
            await speakError("I didn't catch that. Try again?")
            return
        }
        
        // Commit user message immediately — the live transcription bubble
        // transitions seamlessly into a permanent message (no flicker)
        #if DEBUG
        VoiceTrace.trace("message append count=\(messages.count + 1)")
        #endif
        messages.append(ConversationMessage(role: "user", content: text))
        speechManager.transcribedText = ""
        #if DEBUG
        VoiceTrace.trace("transcribedText cleared")
        #endif
        
        let classifier = IntentClassifier()
        let context = IntentClassifier.Context(
            isInClosingFlow: isInClosingFlow,
            hasPendingTasks: !parsedTasks.isEmpty
        )
        let intent = classifier.classify(text, context: context)
        
        switch intent {
        case .confirm:
            isProcessingUtterance = false
            saveTasks(parsedTasks)
            return
        case .reject:
            isProcessingUtterance = false
            dismiss()
            return
        case .dismiss:
            isProcessingUtterance = false
            isInClosingFlow = false
            dismiss()
            return
        case .gratitude:
            let followUp = "You're welcome. Will this be all?"
            isProcessingUtterance = false
            isInClosingFlow = true
            ttsManager.speakWithBoundedSync(text: followUp, boundedWait: 0.75, onTextReveal: { [self] in
                messages.append(ConversationMessage(role: "assistant", content: followUp))
                state = .speaking
            }, onFinish: { [self] in
                state = .listening
                _Concurrency.Task { await speechManager.startRecording() }
            })
            return
        case .taskRequest:
            isInClosingFlow = false
            break
        }
        
        // taskRequest: send to parser and handle response
        #if DEBUG
        VoiceTrace.trace("state -> processing, handleUserUtterance")
        #endif
        await handleUserUtterance(text)
        isProcessingUtterance = false
        #if DEBUG
        VoiceTrace.trace("stopRecording exit")
        #endif
    }
    
    private func speakError(_ message: String) async {
        state = .speaking
        ttsManager.speak(message) {
            state = .idle
        }
    }
    
    /// Builds TaskContext array from active tasks (capped at 50 for context window)
    private func buildTaskContext() -> [TaskContext] {
        let tasksToSend = Array(activeTasks.prefix(50))
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        let dateTimeFormatter = DateFormatter()
        dateTimeFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        dateTimeFormatter.timeZone = TimeZone.current
        
        return tasksToSend.map { task in
            let dueDateString: String?
            if let dueDate = task.dueDate {
                if task.hasTime {
                    dueDateString = dateTimeFormatter.string(from: dueDate)
                } else {
                    dueDateString = dateFormatter.string(from: dueDate)
                }
            } else {
                dueDateString = nil
            }
            
            let priorityString: String = {
                switch task.priority {
                case .low: return "low"
                case .high: return "high"
                default: return "medium"
                }
            }()
            
            return TaskContext(
                id: task.id.uuidString,
                title: task.title,
                dueDate: dueDateString,
                priority: priorityString,
                category: task.category,
                isCompleted: task.isCompleted,
                progressPercentage: task.progressPercentage,
                isProgressEnabled: task.isProgressEnabled
            )
        }
    }
    
    /// Builds GroceryStoreContext array from grocery store templates
    private func buildGroceryStoreContext() -> [GroceryStoreContext] {
        return groceryStores.map { store in
            GroceryStoreContext(
                name: store.name,
                itemCount: store.items.count
            )
        }
    }
    
    private func handleUserUtterance(_ text: String) async {
        // Check network connectivity before making AI call
        guard networkMonitor.isConnected else {
            await speakError("You're offline right now. I'll need a connection to process that.")
            state = .idle
            return
        }
        
        // User message already committed in stopRecording() for seamless transition
        #if DEBUG
        VoiceTrace.trace("state -> processing")
        #endif
        state = .processing
        errorMessage = nil
        
        // Build task context (only incomplete tasks, capped at 50)
        let existingTasks = buildTaskContext()
        
        // Build grocery store context
        let groceryStoresContext = buildGroceryStoreContext()
        
        do {
            let response = try await parser.send(messages: messages, existingTasks: existingTasks, groceryStores: groceryStoresContext)
            
            // Reset timeout on successful response
            startConversationTimeout()
            
            // Handle different response types
            if response.type == "update" {
                await handleUpdateResponse(response)
            } else if response.type == "delete" {
                await handleDeleteResponse(response)
            } else if response.type == "complete" {
                // Replace parsedTasks (handles corrections)
                parsedTasks = response.tasks ?? []
                
                // Check if this is a correction to recently saved tasks
                let isCorrection = !lastSavedTasks.isEmpty && !parsedTasks.isEmpty
                print("[Voice] complete — isCorrection: \(isCorrection), lastSaved: \(lastSavedTasks.count), parsed: \(parsedTasks.count)")
                if isCorrection {
                    for t in parsedTasks { print("[Voice]   corrected task: \(t.title)") }
                    for t in lastSavedTasks { print("[Voice]   saved task: \(t.title)") }
                }

                // Share confirmation flow: when any task has shareWith (and not a correction)
                if !isCorrection, let firstShareWith = parsedTasks.first(where: { $0.shareWith != nil })?.shareWith {
                    let contact = await resolveContact(nameOrEmail: firstShareWith)
                    if let contact = contact {
                        // Show confirmation card
                        pendingShareConfirmation = PendingShareConfirmation(tasks: parsedTasks, contact: contact)
                        let confirmText = "I'll share this with \(contact.contactName ?? contact.contactEmail). How would you like to send it? Docket, email, or text."
                        ttsManager.speakWithBoundedSync(text: confirmText, boundedWait: 0.75, onTextReveal: { [self] in
                            state = .speaking
                            messages.append(ConversationMessage(role: "assistant", content: confirmText))
                        }, onFinish: { [self] in
                            state = .complete
                        })
                        return
                    } else {
                        // No match — speak error, show in chat, then save without share
                        var tasksToSave = parsedTasks
                        for i in tasksToSave.indices where tasksToSave[i].shareWith == firstShareWith {
                            tasksToSave[i].shareWith = nil
                        }
                        let errorText = "I couldn't find \(firstShareWith) in your contacts. I'll add the task without sharing."
                        ttsManager.speakWithBoundedSync(text: errorText, boundedWait: 0.75, onTextReveal: { [self] in
                            messages.append(ConversationMessage(role: "assistant", content: errorText))
                            state = .speaking
                        }, onFinish: { [self] in
                            saveTasks(tasksToSave)
                        })
                        return
                    }
                }
                
                if let summary = response.summary {
                    #if DEBUG
                    VoiceTrace.trace("state -> speaking (complete)")
                    #endif
                    let needsConfirmation = summary.contains("?")
                    ttsManager.speakWithBoundedSync(text: summary, boundedWait: 0.75, onTextReveal: { [self] in
                        state = .speaking
                        messages.append(ConversationMessage(role: "assistant", content: summary))
                    }, onFinish: { [self] in
                        if isCorrection {
                            updateSavedTasks(with: parsedTasks)
                        } else if parsedTasks.isEmpty {
                            state = .listening
                            _Concurrency.Task { await speechManager.startRecording() }
                        } else if needsConfirmation {
                            state = .listening
                            _Concurrency.Task { await speechManager.startRecording() }
                        } else {
                            saveTasks(parsedTasks)
                        }
                    })
                } else {
                    if isCorrection {
                        updateSavedTasks(with: parsedTasks)
                    } else {
                        // Resolve share names before showing confirmation
                        for i in parsedTasks.indices {
                            if let shareWith = parsedTasks[i].shareWith {
                                if shareWith.contains("@") {
                                    parsedTasks[i].resolvedShareEmail = shareWith.lowercased()
                                } else {
                                    parsedTasks[i].resolvedShareEmail = await resolveNameToEmail(shareWith)
                                }
                            }
                        }
                        showingConfirmation = true
                        state = .complete
                    }
                }
            } else {
                let question = response.text ?? ""
                ttsManager.speakWithBoundedSync(text: question, boundedWait: 0.75, onTextReveal: { [self] in
                    messages.append(ConversationMessage(role: "assistant", content: question))
                    state = .speaking
                }, onFinish: { [self] in
                    state = .listening
                    _Concurrency.Task { await speechManager.startRecording() }
                })
            }
        } catch {
            // Error haptic
            let errorGenerator = UINotificationFeedbackGenerator()
            errorGenerator.prepare()
            errorGenerator.notificationOccurred(.error)
            
            errorMessage = "Something went wrong. Want to try again?"
            await speakError("Something went wrong. Want to try again?")
            state = .idle
        }
    }
    
    private func saveTasks(_ tasks: [ParsedTask]) {
        cancelConversationTimeout()
        
        guard !tasks.isEmpty else {
            isInClosingFlow = true
            let followUp = "Got it. Anything else?"
            ttsManager.speakWithBoundedSync(text: followUp, boundedWait: 0.75, onTextReveal: { [self] in
                messages.append(ConversationMessage(role: "assistant", content: followUp))
                state = .speaking
            }, onFinish: { [self] in
                state = .listening
                _Concurrency.Task { await speechManager.startRecording() }
            })
            return
        }
        
        // Haptic feedback for success
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        
        _Concurrency.Task {
            var savedTasks: [Task] = []
            
            for parsedTask in tasks {
                // Convert priority string to enum
                let priority: Priority = {
                    switch parsedTask.priority.lowercased() {
                    case "low": return .low
                    case "high": return .high
                    default: return .medium
                    }
                }()
                
                // Create Task
                let task = Task(
                    title: parsedTask.title,
                    dueDate: parsedTask.dueDate,
                    hasTime: parsedTask.hasTime,
                    priority: priority,
                    category: parsedTask.category,
                    notes: parsedTask.notes,
                    syncStatus: .pending,
                    isProgressEnabled: progressTrackingDefault
                )
                
                // Handle checklist items
                if let templateName = parsedTask.useTemplate {
                    // Load items from grocery store template
                    if let store = groceryStores.first(where: { $0.name.localizedCaseInsensitiveContains(templateName) }) {
                        let items = store.items.enumerated().map { index, name in
                            ChecklistItem(
                                id: UUID(),
                                name: name,
                                isChecked: false,
                                sortOrder: index,
                                quantity: 1,
                                isStarred: false
                            )
                        }
                        task.checklistItems = items
                    }
                } else if let itemNames = parsedTask.checklistItems, !itemNames.isEmpty {
                    // Create checklist items from AI-suggested names
                    let items = itemNames.enumerated().map { index, name in
                        // Capitalize item name (title case: "banana" -> "Banana", "frozen yogurt" -> "Frozen Yogurt")
                        let capitalizedName = name.split(separator: " ")
                            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                            .joined(separator: " ")
                        
                        return ChecklistItem(
                            id: UUID(),
                            name: capitalizedName,
                            isChecked: false,
                            sortOrder: index,
                            quantity: 1,
                            isStarred: false
                        )
                    }
                    task.checklistItems = items
                }
                
                // Insert into SwiftData
                modelContext.insert(task)
                savedTasks.append(task)
                
                // Schedule notification if due date exists
                if parsedTask.dueDate != nil {
                    await NotificationManager.shared.scheduleNotification(for: task)
                }
                
                // Push to sync engine
                await syncEngine.pushTask(task)
                
                // Handle sharing if needed
                if let shareWith = parsedTask.shareWith {
                    await createShare(for: task, shareWith: shareWith)
                }
            }
            
            // Save context
            try? modelContext.save()
            
            // Remember saved tasks for potential corrections
            lastSavedTasks = savedTasks
            
            // Clear parsed tasks so we're ready for a new round
            parsedTasks = []
            
            // Ask if the user wants to add more tasks
            isInClosingFlow = true
            let taskCount = tasks.count
            let followUp = taskCount == 1 ? "Done! Anything else?" : "All \(taskCount) added! Anything else?"
            ttsManager.speakWithBoundedSync(text: followUp, boundedWait: 0.75, onTextReveal: { [self] in
                messages.append(ConversationMessage(role: "assistant", content: followUp))
                state = .speaking
            }, onFinish: { [self] in
                state = .listening
                _Concurrency.Task { await speechManager.startRecording() }
            })
        }
    }
    
    /// Updates previously saved tasks with corrected values from the AI
    private func updateSavedTasks(with correctedTasks: [ParsedTask]) {
        cancelConversationTimeout()
        
        // Haptic feedback for success
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        
        _Concurrency.Task {
            for correctedTask in correctedTasks {
                let priority: Priority = {
                    switch correctedTask.priority.lowercased() {
                    case "low": return .low
                    case "high": return .high
                    default: return .medium
                    }
                }()
                
                // Find matching saved task by title similarity
                if let existingTask = findMatchingTask(for: correctedTask) {
                    print("[Voice] ✓ matched '\(correctedTask.title)' → updating '\(existingTask.title)'")
                    // Update the existing task
                    existingTask.title = correctedTask.title
                    existingTask.dueDate = correctedTask.dueDate
                    existingTask.hasTime = correctedTask.hasTime
                    existingTask.priority = priority
                    existingTask.category = correctedTask.category
                    existingTask.notes = correctedTask.notes
                    existingTask.syncStatusEnum = .pending
                    existingTask.updatedAt = Date()
                    
                    // Re-schedule notification
                    if correctedTask.dueDate != nil {
                        await NotificationManager.shared.scheduleNotification(for: existingTask)
                    }
                    
                    // Re-push to sync
                    await syncEngine.pushTask(existingTask)
                } else {
                    print("[Voice] ✗ no match for '\(correctedTask.title)' — creating new")
                    // No match found — create as new task
                    let task = Task(
                        title: correctedTask.title,
                        dueDate: correctedTask.dueDate,
                        hasTime: correctedTask.hasTime,
                        priority: priority,
                        category: correctedTask.category,
                        notes: correctedTask.notes,
                        syncStatus: .pending
                    )
                    modelContext.insert(task)
                    lastSavedTasks.append(task)
                    
                    if correctedTask.dueDate != nil {
                        await NotificationManager.shared.scheduleNotification(for: task)
                    }
                    await syncEngine.pushTask(task)
                }
            }
            
            // Save context
            try? modelContext.save()
            
            // Clear parsed tasks
            parsedTasks = []
            
            // Confirm and ask for more
            isInClosingFlow = true
            let followUp = "Updated! Anything else?"
            ttsManager.speakWithBoundedSync(text: followUp, boundedWait: 0.75, onTextReveal: { [self] in
                messages.append(ConversationMessage(role: "assistant", content: followUp))
                state = .speaking
            }, onFinish: { [self] in
                state = .listening
                _Concurrency.Task { await speechManager.startRecording() }
            })
        }
    }
    
    /// Finds a matching task from lastSavedTasks by title similarity
    private func findMatchingTask(for parsedTask: ParsedTask) -> Task? {
        let correctedTitle = parsedTask.title.lowercased()
        
        // First try exact match
        if let exact = lastSavedTasks.first(where: { $0.title.lowercased() == correctedTitle }) {
            return exact
        }
        
        // Then try containment match (e.g. "Meeting with David" matches "Meeting with David at office")
        if let partial = lastSavedTasks.first(where: {
            correctedTitle.contains($0.title.lowercased()) || $0.title.lowercased().contains(correctedTitle)
        }) {
            return partial
        }
        
        // If only one task was saved, the correction almost certainly refers to it
        if lastSavedTasks.count == 1 {
            return lastSavedTasks.first
        }
        
        return nil
    }
    
    private func createShare(for task: Task, shareWith: String) async {
        do {
            let session = try await SupabaseConfig.client.auth.session
            let ownerId = session.user.id.uuidString
            
            // Check if shareWith is an email or a name
            let isEmail = shareWith.contains("@")
            let sharedWithEmail: String
            
            if isEmail {
                sharedWithEmail = shareWith.lowercased()
            } else {
                // Try to resolve name to email from contacts
                if let resolved = await resolveNameToEmail(shareWith) {
                    sharedWithEmail = resolved
                } else {
                    // Name not found — speak TTS feedback
                    await MainActor.run {
                        ttsManager.speak("I couldn't find \(shareWith) in your contacts.") {
                            // No-op on finish
                        }
                    }
                    sharedWithEmail = shareWith.lowercased() // use as fallback for invite
                }
            }
            
            struct TaskShareInsert: Codable {
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
            
            let shareInsert = TaskShareInsert(
                taskId: task.id,
                ownerId: ownerId,
                sharedWithEmail: sharedWithEmail,
                status: "pending"
            )
            
            try await SupabaseConfig.client
                .from("task_shares")
                .insert(shareInsert)
                .execute()
        } catch {
            print("Failed to create share: \(error)")
            // Don't block task creation if share fails
        }
    }
    
    private func resolveNameToEmail(_ name: String) async -> String? {
        await resolveContact(nameOrEmail: name)?.contactEmail
    }

    /// Resolves a name or email to a ContactRecord using fuzzy matching.
    private func resolveContact(nameOrEmail: String) async -> ContactRecord? {
        do {
            let session = try await SupabaseConfig.client.auth.session
            let userId = session.user.id.uuidString
            let contacts: [ContactRecord] = try await SupabaseConfig.client
                .from("contacts")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value

            let trimmed = nameOrEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("@") {
                return contacts.first { $0.contactEmail.lowercased() == trimmed.lowercased() }
            }
            return FuzzyContactMatcher.resolveContact(name: trimmed, from: contacts)
        } catch {
            return nil
        }
    }

    private func performShare(method: ShareMethod) {
        guard let pending = pendingShareConfirmation else { return }
        let contact = pending.contact
        let tasks = pending.tasks

        _Concurrency.Task {
            var savedTasks: [Task] = []
            for parsedTask in tasks {
                let priority: Priority = {
                    switch parsedTask.priority.lowercased() {
                    case "low": return .low
                    case "high": return .high
                    default: return .medium
                    }
                }()
                let task = Task(
                    title: parsedTask.title,
                    dueDate: parsedTask.dueDate,
                    hasTime: parsedTask.hasTime,
                    priority: priority,
                    category: parsedTask.category,
                    notes: parsedTask.notes,
                    syncStatus: .pending,
                    isProgressEnabled: progressTrackingDefault
                )
                if let templateName = parsedTask.useTemplate,
                   let store = groceryStores.first(where: { $0.name.localizedCaseInsensitiveContains(templateName) }) {
                    task.checklistItems = store.items.enumerated().map { index, name in
                        ChecklistItem(id: UUID(), name: name, isChecked: false, sortOrder: index, quantity: 1, isStarred: false)
                    }
                } else if let itemNames = parsedTask.checklistItems, !itemNames.isEmpty {
                    task.checklistItems = itemNames.enumerated().map { index, name in
                        let capitalizedName = name.split(separator: " ")
                            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                            .joined(separator: " ")
                        return ChecklistItem(id: UUID(), name: capitalizedName, isChecked: false, sortOrder: index, quantity: 1, isStarred: false)
                    }
                }
                modelContext.insert(task)
                savedTasks.append(task)
                if parsedTask.dueDate != nil {
                    await NotificationManager.shared.scheduleNotification(for: task)
                }
                await syncEngine.pushTask(task)
            }
            try? modelContext.save()
            await MainActor.run {
                lastSavedTasks = savedTasks
                parsedTasks = []
            }

            let taskTitle = tasks.first?.title ?? "Task"
            let userExists = await checkUserExists(email: contact.contactEmail)
            let firstName = contact.contactName ?? contact.contactEmail

            switch method {
            case .docket:
                if contact.contactUserId != nil, let task = savedTasks.first {
                    await createShare(for: task, shareWith: contact.contactEmail)
                    await MainActor.run {
                        pendingShareConfirmation = nil
                        ttsManager.speak("Shared with \(firstName) on Docket.") { }
                        askAnythingElse()
                    }
                }
            case .email:
                let body = userExists
                    ? "I shared \"\(taskTitle)\" with you on Docket. Open the app to see it!\n\n\(appStoreURL)"
                    : "I shared \"\(taskTitle)\" with you on Docket. Download the app to see it: \(appStoreURL)"
                await MainActor.run {
                    composeRecipient = contact.contactEmail
                    composeSubject = "Task shared: \(taskTitle)"
                    composeBody = body
                    composeEmailForRecord = contact.contactEmail
                    composeContactName = contact.contactName ?? contact.contactEmail
                    createdTaskForShare = savedTasks.first
                    showMailCompose = true
                    pendingShareConfirmation = nil
                }
            case .text:
                let phone = (contact.contactPhone ?? "").strippedPhoneNumber
                guard !phone.isEmpty else { return }
                let body = userExists
                    ? "I shared \"\(taskTitle)\" with you on Docket. Open the app to see it!\n\(appStoreURL)"
                    : "I shared \"\(taskTitle)\" with you on Docket. Download the app to see it: \(appStoreURL)"
                await MainActor.run {
                    composeRecipient = phone
                    composeBody = body
                    composeEmailForRecord = contact.contactEmail
                    composeContactName = contact.contactName ?? contact.contactEmail
                    createdTaskForShare = savedTasks.first
                    showTextCompose = true
                    pendingShareConfirmation = nil
                }
            }
        }
    }

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
        } catch { return false }
    }

    private func recordShare(taskId: UUID, recipient: String) {
        _Concurrency.Task {
            do {
                let session = try await SupabaseConfig.client.auth.session
                let ownerId = session.user.id.uuidString
                struct TaskShareInsert: Codable {
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
                try await SupabaseConfig.client
                    .from("task_shares")
                    .insert(TaskShareInsert(taskId: taskId, ownerId: ownerId, sharedWithEmail: recipient, status: "pending"))
                    .execute()
            } catch {
                print("[Voice] recordShare failed: \(error)")
            }
        }
    }

    private func askAnythingElse() {
        isInClosingFlow = true
        let followUp = "Anything else?"
        ttsManager.speakWithBoundedSync(text: followUp, boundedWait: 0.75, onTextReveal: { [self] in
            messages.append(ConversationMessage(role: "assistant", content: followUp))
            state = .speaking
        }, onFinish: { [self] in
            state = .listening
            _Concurrency.Task { await speechManager.startRecording() }
        })
    }
    
    /// Handles "update" response type - modifies an existing task
    private func handleUpdateResponse(_ response: ParseResponse) async {
        cancelConversationTimeout()
        
        guard let taskIdString = response.taskId,
              let taskId = UUID(uuidString: taskIdString),
              let changes = response.changes else {
            print("[Voice] update response missing taskId or changes")
            await speakError("I couldn't find which task to update. Try again?")
            state = .idle
            return
        }
        
        // Find task in SwiftData
        let descriptor = FetchDescriptor<Task>(
            predicate: #Predicate<Task> { $0.id == taskId }
        )
        
        guard let task = try? modelContext.fetch(descriptor).first else {
            print("[Voice] task not found: \(taskIdString)")
            await speakError("I couldn't find that task. Try again?")
            state = .idle
            return
        }
        
        // Apply changes
        if let newTitle = changes.title {
            task.title = newTitle
        }
        
        if changes.dueDate != nil {
            let (date, hasTime) = changes.decodeDueDate()
            task.dueDate = date
            task.hasTime = hasTime
        }
        
        if let newPriority = changes.priority {
            let priority: Priority = {
                switch newPriority.lowercased() {
                case "low": return .low
                case "high": return .high
                default: return .medium
                }
            }()
            task.priority = priority
        }
        
        if let newCategory = changes.category {
            task.category = newCategory
        }
        
        if let newNotes = changes.notes {
            task.notes = newNotes
        }
        
        if let isCompleted = changes.isCompleted {
            task.isCompleted = isCompleted
            if isCompleted {
                task.completedAt = Date()
            } else {
                task.completedAt = nil
            }
        }
        
        if let isPinned = changes.isPinned {
            task.isPinned = isPinned
        }
        
        if let progress = changes.progressPercentage {
            task.progressPercentage = min(max(progress, 0), 100)
            task.lastProgressUpdate = Date()
            if progress >= 100 {
                task.isCompleted = true
                task.completedAt = Date()
            }
        }
        
        // Handle checklist operations
        var currentItems = task.checklistItems ?? []
        
        // Add items
        if let itemsToAdd = changes.addChecklistItems, !itemsToAdd.isEmpty {
            let maxSortOrder = currentItems.map { $0.sortOrder }.max() ?? -1
            let newItems = itemsToAdd.enumerated().map { index, name in
                // Capitalize item name (title case: "banana" -> "Banana", "frozen yogurt" -> "Frozen Yogurt")
                let capitalizedName = name.split(separator: " ")
                    .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                    .joined(separator: " ")
                
                return ChecklistItem(
                    id: UUID(),
                    name: capitalizedName,
                    isChecked: false,
                    sortOrder: maxSortOrder + 1 + index,
                    quantity: 1,
                    isStarred: false
                )
            }
            currentItems.append(contentsOf: newItems)
        }
        
        // Remove items (case-insensitive name matching)
        if let itemsToRemove = changes.removeChecklistItems, !itemsToRemove.isEmpty {
            let lowercasedToRemove = itemsToRemove.map { $0.lowercased() }
            currentItems.removeAll { item in
                lowercasedToRemove.contains { $0 == item.name.lowercased() }
            }
            // Re-normalize sortOrder after removal
            currentItems = currentItems.enumerated().map { index, item in
                var updated = item
                updated.sortOrder = index
                return updated
            }
        }
        
        // Star items
        if let itemsToStar = changes.starChecklistItems, !itemsToStar.isEmpty {
            let lowercasedToStar = itemsToStar.map { $0.lowercased() }
            currentItems = currentItems.map { item in
                var updated = item
                if lowercasedToStar.contains(where: { $0 == item.name.lowercased() }) {
                    updated.isStarred = true
                }
                return updated
            }
        }
        
        // Unstar items
        if let itemsToUnstar = changes.unstarChecklistItems, !itemsToUnstar.isEmpty {
            let lowercasedToUnstar = itemsToUnstar.map { $0.lowercased() }
            currentItems = currentItems.map { item in
                var updated = item
                if lowercasedToUnstar.contains(where: { $0 == item.name.lowercased() }) {
                    updated.isStarred = false
                }
                return updated
            }
        }
        
        // Check items
        if let itemsToCheck = changes.checkChecklistItems, !itemsToCheck.isEmpty {
            let lowercasedToCheck = itemsToCheck.map { $0.lowercased() }
            currentItems = currentItems.map { item in
                var updated = item
                if lowercasedToCheck.contains(where: { $0 == item.name.lowercased() }) {
                    updated.isChecked = true
                }
                return updated
            }
        }
        
        // Uncheck items
        if let itemsToUncheck = changes.uncheckChecklistItems, !itemsToUncheck.isEmpty {
            let lowercasedToUncheck = itemsToUncheck.map { $0.lowercased() }
            currentItems = currentItems.map { item in
                var updated = item
                if lowercasedToUncheck.contains(where: { $0 == item.name.lowercased() }) {
                    updated.isChecked = false
                }
                return updated
            }
        }
        
        // Update task's checklistItems if any operations were performed
        if changes.addChecklistItems != nil || changes.removeChecklistItems != nil ||
           changes.starChecklistItems != nil || changes.unstarChecklistItems != nil ||
           changes.checkChecklistItems != nil || changes.uncheckChecklistItems != nil {
            task.checklistItems = currentItems.isEmpty ? nil : currentItems
        }
        
        // Mark as pending sync
        task.syncStatusEnum = .pending
        task.updatedAt = Date()
        
        // Re-schedule notification if due date changed
        if changes.dueDate != nil {
            await NotificationManager.shared.scheduleNotification(for: task)
        }
        
        // Push to sync
        await syncEngine.pushTask(task)
        
        // Save context
        try? modelContext.save()
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        
        // TTS readback
        if let summary = response.summary {
            ttsManager.speakWithBoundedSync(text: summary, boundedWait: 0.75, onTextReveal: { [self] in
                messages.append(ConversationMessage(role: "assistant", content: summary))
                state = .speaking
            }, onFinish: { [self] in
                startConversationTimeout()
                state = .listening
                _Concurrency.Task { await speechManager.startRecording() }
            })
        } else {
            startConversationTimeout()
            state = .listening
            _Concurrency.Task { await speechManager.startRecording() }
        }
    }
    
    /// Handles "delete" response type - removes an existing task
    private func handleDeleteResponse(_ response: ParseResponse) async {
        cancelConversationTimeout()
        
        guard let taskIdString = response.taskId,
              let taskId = UUID(uuidString: taskIdString) else {
            print("[Voice] delete response missing taskId")
            await speakError("I couldn't find which task to delete. Try again?")
            state = .idle
            return
        }
        
        // Find task in SwiftData
        let descriptor = FetchDescriptor<Task>(
            predicate: #Predicate<Task> { $0.id == taskId }
        )
        
        guard let task = try? modelContext.fetch(descriptor).first else {
            print("[Voice] task not found for deletion: \(taskIdString)")
            await speakError("I couldn't find that task. Try again?")
            state = .idle
            return
        }
        
        // Delete from remote first (if synced)
        if task.syncStatusEnum == .synced {
            await syncEngine.deleteRemoteTask(id: task.id, syncStatus: task.syncStatus)
        }
        
        // Delete from SwiftData
        modelContext.delete(task)
        try? modelContext.save()
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        
        // TTS readback
        if let summary = response.summary {
            ttsManager.speakWithBoundedSync(text: summary, boundedWait: 0.75, onTextReveal: { [self] in
                messages.append(ConversationMessage(role: "assistant", content: summary))
                state = .speaking
            }, onFinish: { [self] in
                startConversationTimeout()
                state = .listening
                _Concurrency.Task { await speechManager.startRecording() }
            })
        } else {
            startConversationTimeout()
            state = .listening
            _Concurrency.Task { await speechManager.startRecording() }
        }
    }
}

struct AIThinkingIndicator: View {
    let label: String
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .opacity(isAnimating ? 1.0 : 0.25)
                        .scaleEffect(isAnimating ? 1.0 : 0.7)
                        .animation(
                            .easeInOut(duration: 0.55)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.14),
                            value: isAnimating
                        )
                }
            }
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
        .onAppear { isAnimating = true }
        .onDisappear { isAnimating = false }
    }
}

/// Lightweight wrapper so committed messages and live transcription share one identity space
struct DisplayMessage: Identifiable {
    let id: String
    let message: ConversationMessage
}

struct MessageBubble: View {
    let message: ConversationMessage
    
    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer(minLength: 48)
            }
            
            Text(message.content)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    message.role == "user" ? Color.blue : Color(.systemGray5)
                )
                .foregroundStyle(
                    message.role == "user" ? .white : .primary
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
            
            if message.role == "assistant" {
                Spacer(minLength: 48)
            }
        }
    }
}

#Preview {
    VoiceRecordingView()
}
