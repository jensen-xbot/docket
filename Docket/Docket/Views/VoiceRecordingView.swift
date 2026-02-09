import SwiftUI
import SwiftData
import _Concurrency

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
    @AppStorage("useWhisperTranscription") private var useWhisperTranscription = false
    private let conversationTimeoutSeconds: TimeInterval = 60
    
    /// Combines committed messages with the live transcription into a single list.
    /// The live text gets the ID "msg-N" (where N = messages.count), which is the
    /// exact same ID it will have once committed to `messages`. This means SwiftUI
    /// treats the live bubble and the committed bubble as the SAME view — no
    /// disappear/reappear flash on transition.
    private var displayMessages: [DisplayMessage] {
        var result = messages.enumerated().map { index, msg in
            DisplayMessage(id: "msg-\(index)", message: msg)
        }
        if state == .listening && !speechManager.transcribedText.isEmpty && !isProcessingUtterance {
            result.append(DisplayMessage(
                id: "msg-\(messages.count)",
                message: ConversationMessage(role: "user", content: speechManager.transcribedText)
            ))
        }
        return result
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("Voice Task")
                        .font(.headline)
                    
                    Spacer()
                    
                    // Placeholder for future actions
                    Color.clear
                        .frame(width: 60)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                
                // Conversation history
                GeometryReader { geometry in
                    ScrollViewReader { scrollProxy in
                        ScrollView {
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
                                    HStack(spacing: 8) {
                                        HStack(spacing: 4) {
                                            ForEach(0..<3) { index in
                                                Circle()
                                                    .fill(Color.blue)
                                                    .frame(width: 8, height: 8)
                                                    .opacity(0.3)
                                                    .scaleEffect(state == .processing ? 1.0 : 0.5)
                                                    .animation(
                                                        .easeInOut(duration: 0.6)
                                                            .repeatForever()
                                                            .delay(Double(index) * 0.2),
                                                        value: state == .processing
                                                    )
                                            }
                                        }
                                        Text("Processing...")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .id("processing")
                                }
                                
                                // TTS generating indicator (when OpenAI TTS is loading)
                                if state == .speaking && ttsManager.isGeneratingTTS {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Preparing voice...")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .id("tts-loading")
                                }
                                
                                // Scroll anchor
                                Color.clear
                                    .frame(height: 1)
                                    .id("bottom")
                            }
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: geometry.size.height, alignment: .bottom)
                        }
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
        .onAppear {
            _Concurrency.Task {
                let hasPermissions = await speechManager.requestPermissions()
                if !hasPermissions {
                    errorMessage = speechManager.errorMessage ?? "Microphone and speech recognition permissions are required."
                }
            }
        }
        .onDisappear {
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
                TaskConfirmationView(tasks: parsedTasks, onConfirm: saveTasks, onCancel: { dismiss() })
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
    
    private func stopRecording() async {
        guard !isProcessingUtterance else { return }
        isProcessingUtterance = true
        
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
        
        // Check for empty transcription
        guard !text.isEmpty else {
            state = .idle
            isProcessingUtterance = false
            await speakError("I didn't catch that. Try again?")
            return
        }
        
        // Commit user message immediately — the live transcription bubble
        // transitions seamlessly into a permanent message (no flicker)
        messages.append(ConversationMessage(role: "user", content: text))
        speechManager.transcribedText = ""
        
        // Check if this is a confirmation after tasks are ready
        if !parsedTasks.isEmpty {
            if isConfirmation(text) {
                // User confirmed - save tasks
                isProcessingUtterance = false
                saveTasks(parsedTasks)
                return
            } else if isRejection(text) {
                // User rejected - cancel
                isProcessingUtterance = false
                dismiss()
                return
            }
            // Otherwise treat as correction/new input — falls through
        }
        
        // Check if user wants to stop after "Anything else?"
        // (parsedTasks is empty after save, so check for dismissal phrases)
        if isDismissal(text) {
            isProcessingUtterance = false
            dismiss()
            return
        }
        
        // Normal flow - send to parser and handle response
        await handleUserUtterance(text)
        isProcessingUtterance = false
    }
    
    private func speakError(_ message: String) async {
        state = .speaking
        ttsManager.speak(message) {
            state = .idle
        }
    }
    
    /// Checks if any phrase matches as a whole word/phrase (not substring).
    /// Prevents "note" from matching "no", "sure thing" from false-matching, etc.
    private func matchesPhrase(_ text: String, phrases: [String]) -> Bool {
        let lowercased = text.lowercased()
        for phrase in phrases {
            // Use word boundary regex: \b ensures "no" doesn't match inside "note"
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: phrase))\\b"
            if lowercased.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }
    
    private func isConfirmation(_ text: String) -> Bool {
        let confirmations = ["yes", "yeah", "yep", "sure", "ok", "okay", "add it", "add them", "add all", "confirm", "sounds good", "that's right", "correct"]
        return matchesPhrase(text, phrases: confirmations)
    }
    
    private func isRejection(_ text: String) -> Bool {
        let rejections = ["no", "nope", "cancel", "never mind", "forget it", "don't", "stop"]
        return matchesPhrase(text, phrases: rejections)
    }
    
    private func isDismissal(_ text: String) -> Bool {
        let dismissals = ["no", "nope", "no thanks", "that's all", "that's it", "i'm done", "i'm good", "nothing", "all done", "all good"]
        return matchesPhrase(text, phrases: dismissals)
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
                isCompleted: task.isCompleted
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
                
                if let summary = response.summary {
                    state = .speaking
                    messages.append(ConversationMessage(role: "assistant", content: summary))
                    
                    // Corrections always go through updateSavedTasks — regardless of "?"
                    if isCorrection {
                        print("[Voice] → correction path")
                        ttsManager.speak(summary) { [self] in
                            updateSavedTasks(with: parsedTasks)
                        }
                    } else {
                        // Check if the AI is asking for confirmation or just doing it.
                        let needsConfirmation = summary.contains("?")
                        
                        ttsManager.speak(summary) { [self] in
                            if needsConfirmation {
                                // AI asked a question — listen for "yes"/"no"
                                state = .listening
                                _Concurrency.Task {
                                    await speechManager.startRecording()
                                }
                            } else {
                                // AI is confirming it's done — save immediately
                                saveTasks(parsedTasks)
                            }
                        }
                    }
                } else {
                    if isCorrection {
                        updateSavedTasks(with: parsedTasks)
                    } else {
                        // No summary — show confirmation UI
                        showingConfirmation = true
                        state = .complete
                    }
                }
            } else {
                let question = response.text ?? ""
                messages.append(ConversationMessage(role: "assistant", content: question))
                state = .speaking
                ttsManager.speak(question) {
                    state = .listening
                    _Concurrency.Task {
                        await speechManager.startRecording()
                    }
                }
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
                    syncStatus: .pending
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
            let taskCount = tasks.count
            let followUp = taskCount == 1 ? "Done! Anything else?" : "All \(taskCount) added! Anything else?"
            messages.append(ConversationMessage(role: "assistant", content: followUp))
            state = .speaking
            ttsManager.speak(followUp) { [self] in
                // Listen for next task or dismissal
                state = .listening
                _Concurrency.Task {
                    await speechManager.startRecording()
                }
            }
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
            let followUp = "Updated! Anything else?"
            messages.append(ConversationMessage(role: "assistant", content: followUp))
            state = .speaking
            ttsManager.speak(followUp) { [self] in
                state = .listening
                _Concurrency.Task {
                    await speechManager.startRecording()
                }
            }
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
                sharedWithEmail = await resolveNameToEmail(shareWith) ?? shareWith.lowercased()
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
        do {
            // Query contacts table for matching name
            struct ContactRecord: Codable {
                let contactEmail: String
                
                enum CodingKeys: String, CodingKey {
                    case contactEmail = "contact_email"
                }
            }
            
            let session = try await SupabaseConfig.client.auth.session
            let userId = session.user.id.uuidString
            
            let contacts: [ContactRecord] = try await SupabaseConfig.client
                .from("contacts")
                .select("contact_email")
                .eq("user_id", value: userId)
                .ilike("contact_name", pattern: name)
                .limit(1)
                .execute()
                .value
            
            return contacts.first?.contactEmail
        } catch {
            return nil
        }
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
            state = .speaking
            messages.append(ConversationMessage(role: "assistant", content: summary))
            ttsManager.speak(summary) { [self] in
                startConversationTimeout()
                state = .listening
                _Concurrency.Task {
                    await speechManager.startRecording()
                }
            }
        } else {
            // No summary - just continue
            startConversationTimeout()
            state = .listening
            _Concurrency.Task {
                await speechManager.startRecording()
            }
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
            state = .speaking
            messages.append(ConversationMessage(role: "assistant", content: summary))
            ttsManager.speak(summary) { [self] in
                startConversationTimeout()
                state = .listening
                _Concurrency.Task {
                    await speechManager.startRecording()
                }
            }
        } else {
            // No summary - just continue
            startConversationTimeout()
            state = .listening
            _Concurrency.Task {
                await speechManager.startRecording()
            }
        }
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
