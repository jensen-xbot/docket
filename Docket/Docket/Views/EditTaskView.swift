import SwiftUI
import SwiftData
import _Concurrency

struct EditTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncEngine.self) private var syncEngine
    @Query(sort: \GroceryStore.name) private var groceryTemplates: [GroceryStore]
    
    @Bindable var task: Task
    
    @State private var title: String = ""
    @State private var priority: Priority = .medium
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var hasTime: Bool = false
    @State private var dueTime: Date = Date()
    @State private var category: String = ""
    @State private var notes: String = ""
    @State private var checklistItems: [ChecklistItem] = []
    @State private var selectedStore: String = ""
    @State private var showDeleteConfirm = false
    @State private var isEditingCategory = false
    @State private var loadedTemplateName: String? = nil
    
    // Save template prompt
    @State private var showSaveTemplate = false
    @State private var templateName: String = ""
    
    @FocusState private var titleFocused: Bool
    @FocusState private var notesFocused: Bool
    
    @State private var storeStore = StoreStore()
    @State private var modeSwitchRotation: Double = 0
    @State private var isRecurring: Bool = false
    @State private var recurrenceRule: String = "weekly"
    @AppStorage("personalizationEnabled") private var personalizationEnabled = true
    
    private var categoryStore: CategoryStore { CategoryStore.shared }
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    init(task: Task) {
        self.task = task
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: 1. Title
                    TextField("Task title", text: $title, axis: .vertical)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .focused($titleFocused)
                        .padding(.top, 8)
                    
                    Spacer().frame(height: 4)
                    
                    // MARK: 2. Category & Store
                    categorySection
                    
                    // MARK: 3. Checklist
                    if isChecklistCategory || !checklistItems.isEmpty {
                        ChecklistEditorView(
                            items: $checklistItems,
                            onSaveTemplate: { promptSaveTemplate() },
                            autoFocusAdd: false
                        )
                    }
                    
                    // MARK: 4. Priority
                    prioritySection
                    
                    Divider()
                    
                    // MARK: 5. Track Progress / Mark Complete
                    VStack(alignment: .leading, spacing: 8) {
                        if task.isProgressEnabled {
                            Text("Track Progress")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        progressAndCompletedSection
                    }
                    
                    Divider()
                    
                    // MARK: 6. Due Date + Notes (tighter spacing between calendar and notes)
                    VStack(alignment: .leading, spacing: 12) {
                        dueDateSection
                        Divider()
                        // MARK: 7. Notes
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notes")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextField("Add any extra details...", text: $notes, axis: .vertical)
                                .lineLimit(3...8)
                                .focused($notesFocused)
                        }
                    }
                    
                    Divider()
                    
                    // MARK: 8. Delete
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Task")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 200)
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Edit Task")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { updateTask() }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .confirmationDialog("Delete this task?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deleteTask() }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showSaveTemplate) {
                TemplateNameSheet(
                    templateName: $templateName,
                    itemCount: checklistItems.count,
                    onSave: { saveTemplate() },
                    onCancel: { templateName = "" }
                )
            }
            .onAppear {
                title = task.title
                priority = task.priority
                hasDueDate = task.dueDate != nil
                if let due = task.dueDate { dueDate = due }
                hasTime = task.hasTime
                if let due = task.dueDate { dueTime = due }
                category = task.category ?? ""
                notes = task.notes ?? ""
                checklistItems = task.checklistItems ?? []
                isRecurring = task.recurrenceRule != nil
                recurrenceRule = task.recurrenceRule ?? "weekly"
                parseStoreFromTitle()
            }
        }
    }
    
    // MARK: - Category Section (inline chip expansion)
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Category row: selected chip + other chips expand inline
            FlowLayout(spacing: 8) {
                ForEach(categoryStore.categories) { item in
                    let isSelected = category == item.name
                    let chipColor = Color(hex: item.color) ?? .gray
                    
                    // Show selected chip always; show others only when editing
                    if isSelected || isEditingCategory {
                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.caption2)
                                .foregroundStyle(isSelected ? .white : chipColor)
                            Text(item.name)
                                .font(.subheadline)
                                .foregroundStyle(isSelected ? .white : .primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSelected ? chipColor : Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(chipColor, lineWidth: isSelected ? 0 : 1.5)
                        )
                        .cornerRadius(16)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                if isSelected {
                                    // Tap selected chip: toggle expand/collapse
                                    isEditingCategory.toggle()
                                } else {
                                    // Tap another chip: select it, collapse
                                    category = item.name
                                    updateTitleForCategory()
                                    isEditingCategory = false
                                }
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                
                // "No category" chip when nothing selected
                if category.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "tag")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Category")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            isEditingCategory.toggle()
                        }
                    }
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isEditingCategory)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: category)
            
            // Store row: same inline pattern for checklist categories
            if isChecklistCategory {
                storeRow
                
                // Template row
                if !availableTemplates.isEmpty {
                    templateRow
                }
            }
        }
    }
    
    // MARK: - Store Row (inline chip expansion)
    @State private var isEditingStore = false
    
    private var storeRow: some View {
        FlowLayout(spacing: 8) {
            ForEach(storeStore.stores, id: \.self) { store in
                let isSelected = selectedStore == store
                
                if isSelected || isEditingStore {
                    Text(store)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .background(isSelected ? Color.orange : Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 1.5)
                        )
                        .cornerRadius(16)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                if isSelected {
                                    isEditingStore.toggle()
                                } else {
                                    selectedStore = store
                                    updateGroceryTitle()
                                    isEditingStore = false
                                }
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            if selectedStore.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "building.2")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Store")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        isEditingStore.toggle()
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isEditingStore)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selectedStore)
    }
    
    // MARK: - Template Row (inline chip expansion)
    @State private var isEditingTemplate = false
    
    private var templateRow: some View {
        FlowLayout(spacing: 8) {
            ForEach(availableTemplates) { template in
                let isSelected = loadedTemplateName == template.name
                
                if isSelected || isEditingTemplate {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                        Text(template.name)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .background(isSelected ? Color.green : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.clear : Color.green.opacity(0.5), lineWidth: 1.5)
                        )
                    .cornerRadius(16)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            if isSelected {
                                isEditingTemplate.toggle()
                            } else {
                                loadTemplate(template)
                                isEditingTemplate = false
                            }
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            if loadedTemplateName == nil {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Template")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        isEditingTemplate.toggle()
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isEditingTemplate)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: loadedTemplateName)
    }
    
    // MARK: - Priority Section (segmented picker with colored contour)
    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Priority")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Picker("Priority", selection: $priority) {
                ForEach(Priority.allCases, id: \.self) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(priorityContourColor, lineWidth: 2.5)
            )
            .animation(.easeInOut(duration: 0.2), value: priority)
        }
    }
    
    private var priorityContourColor: Color {
        switch priority {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .red
        }
    }
    
    // MARK: - Completion Section (Single row, two modes)
    private var progressAndCompletedSection: some View {
        HStack(spacing: 12) {
            if task.isProgressEnabled {
                // TRACK MODE: ProgressBarIcon left + slider | mode switch right with % inside
                ProgressBarIcon(progress: task.isCompleted ? 100 : task.progressPercentage, size: 22)
                
                Slider(
                    value: Binding(
                        get: { task.isCompleted ? 100 : task.progressPercentage },
                        set: { newValue in
                            task.progressPercentage = newValue
                            task.lastProgressUpdate = Date()
                            if newValue >= 100 {
                                task.isCompleted = true
                                task.completedAt = Date()
                            } else {
                                task.isCompleted = false
                                task.completedAt = nil
                            }
                            task.updatedAt = Date()
                            task.syncStatus = SyncStatus.pending.rawValue
                        }
                    ),
                    in: 0...100,
                    step: 5
                )
                .tint(.blue)
                
                // Mode switch: circular arrows with percentage inside
                modeSwitchButton
            } else {
                // SIMPLE MODE: Checkmark left (tap to complete) | mode switch right
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        task.isCompleted.toggle()
                        task.completedAt = task.isCompleted ? Date() : nil
                        task.updatedAt = Date()
                        task.syncStatus = SyncStatus.pending.rawValue
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(task.isCompleted ? .green : .secondary)
                            .contentTransition(.symbolEffect(.replace))
                        Text(task.isCompleted ? "Completed" : "Mark Complete")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(task.isCompleted ? .green : .primary)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Mode switch: circular arrows
                modeSwitchButton
            }
        }
    }
    
    // MARK: - Mode Switch Button (circular arrows with % inside when tracking)
    private var modeSwitchButton: some View {
        Button {
            // Step 1: Spin the arrows
            withAnimation(.easeInOut(duration: 0.4)) {
                modeSwitchRotation += 360
            }
            // Step 2: Switch mode halfway through the spin
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    task.isProgressEnabled.toggle()
                }
            }
        } label: {
            ZStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color.gray.opacity(0.3))
                
                // Percentage inside the arrows when in Track mode
                if task.isProgressEnabled {
                    Text("\(Int(task.isCompleted ? 100 : task.progressPercentage))")
                        .font(.system(size: 9, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.blue)
                }
            }
            .rotationEffect(.degrees(modeSwitchRotation))
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Due Date Section (SF Symbol tap)
    private var dueDateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                // Calendar icon: always visible, tap to toggle due date
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        hasDueDate.toggle()
                        if !hasDueDate {
                            hasTime = false
                            isRecurring = false
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar")
                            .font(.title2)
                            .foregroundStyle(hasDueDate ? .blue : .secondary)
                            .symbolEffect(.bounce, value: hasDueDate)
                        // "Due Date" label only when calendar is closed
                        if !hasDueDate {
                            Text("Due Date")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                                .transition(.opacity.combined(with: .move(edge: .leading)))
                        }
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                // Recurring: appears when calendar is open, between Calendar and Set Time
                if hasDueDate {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isRecurring.toggle()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "repeat")
                                .font(.title2)
                                .foregroundStyle(isRecurring ? .blue : .secondary)
                                .symbolEffect(.bounce, value: isRecurring)
                            if !hasTime {
                                Text("Recurring")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(isRecurring ? .blue : .primary)
                                    .transition(.opacity.combined(with: .move(edge: .leading)))
                            }
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }
                
                // Clock + Set Time: appears when calendar is open
                if hasDueDate {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            hasTime.toggle()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "clock")
                                .font(.title2)
                                .foregroundStyle(hasTime ? .blue : .secondary)
                                .symbolEffect(.bounce, value: hasTime)
                            Text("Set Time")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(hasTime ? .blue : .primary)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                    
                    if hasTime {
                        Spacer()
                        DatePicker("", selection: $dueTime, displayedComponents: [.hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .transition(.opacity)
                    }
                }
            }
            
            if hasDueDate {
                DatePicker("", selection: $dueDate, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                
                // Recurrence rule picker when recurring is active
                if isRecurring {
                    Picker("Recurrence", selection: $recurrenceRule) {
                        Text("Daily").tag("daily")
                        Text("Weekly").tag("weekly")
                        Text("Monthly").tag("monthly")
                    }
                    .pickerStyle(.segmented)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
    
    private func updateTask() {
        if isChecklistCategory && !checklistItems.isEmpty {
            autoSaveTemplateIfNeeded()
        }
        finalizeUpdate()
    }
    
    private func finalizeUpdate() {
        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.priority = priority
        task.dueDate = hasDueDate ? (hasTime ? combineDateAndTime(date: dueDate, time: dueTime) : dueDate) : nil
        task.hasTime = hasTime
        task.recurrenceRule = hasDueDate && isRecurring ? recurrenceRule : nil
        task.category = category.isEmpty ? nil : category
        task.notes = notes.isEmpty ? nil : notes
        task.checklistItems = checklistItems.isEmpty ? nil : checklistItems
        task.completedAt = task.isCompleted ? (task.completedAt ?? Date()) : nil
        task.updatedAt = Date()
        task.syncStatus = SyncStatus.pending.rawValue
        
        // Voice personalization: detect corrections and send fire-and-forget
        if personalizationEnabled, task.taskSource == "voice", let snapshotData = task.voiceSnapshotData,
           let snapshot = try? JSONDecoder().decode(VoiceSnapshot.self, from: snapshotData) {
            let corrections = collectCorrections(snapshot: snapshot)
            if !corrections.isEmpty {
                VoiceTaskParser().recordCorrections(corrections)
            }
        }
        
        _Concurrency.Task {
            await NotificationManager.shared.scheduleNotification(for: task)
            await syncEngine.pushTask(task)
        }
        dismiss()
    }
    
    private func collectCorrections(snapshot: VoiceSnapshot) -> [CorrectionEntry] {
        var corrections: [CorrectionEntry] = []
        let taskIdStr = task.id.uuidString
        
        let editedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if editedTitle != snapshot.title {
            corrections.append(CorrectionEntry(taskId: taskIdStr, fieldName: "title", originalValue: snapshot.title, correctedValue: editedTitle, category: nil))
        }
        
        let editedCategory = category.isEmpty ? nil : category
        let snapCategory = snapshot.category
        if editedCategory != snapCategory {
            corrections.append(CorrectionEntry(taskId: taskIdStr, fieldName: "category", originalValue: snapCategory, correctedValue: editedCategory, category: nil))
        }
        
        let editedPriority = priority.displayName.lowercased()
        if editedPriority != snapshot.priority.lowercased() {
            corrections.append(CorrectionEntry(taskId: taskIdStr, fieldName: "priority", originalValue: snapshot.priority, correctedValue: editedPriority, category: nil))
        }
        
        let editedDueDateStr: String?
        if hasDueDate {
            let d = hasTime ? combineDateAndTime(date: dueDate, time: dueTime) : dueDate
            if hasTime {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm"
                f.timeZone = TimeZone.current
                editedDueDateStr = f.string(from: d)
            } else {
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withFullDate, .withDashSeparatorInDate]
                f.timeZone = TimeZone.current
                editedDueDateStr = String(f.string(from: d).prefix(10))
            }
        } else {
            editedDueDateStr = nil
        }
        if editedDueDateStr != snapshot.dueDate {
            corrections.append(CorrectionEntry(taskId: taskIdStr, fieldName: "dueDate", originalValue: snapshot.dueDate, correctedValue: editedDueDateStr, category: nil))
        }
        
        if hasTime != snapshot.hasTime {
            corrections.append(CorrectionEntry(taskId: taskIdStr, fieldName: "hasTime", originalValue: String(snapshot.hasTime), correctedValue: String(hasTime), category: task.category))
        }
        
        let editedNotes = notes.isEmpty ? nil : notes
        if editedNotes != snapshot.notes {
            corrections.append(CorrectionEntry(taskId: taskIdStr, fieldName: "notes", originalValue: snapshot.notes, correctedValue: editedNotes, category: nil))
        }
        
        return corrections
    }
    
    private func deleteTask() {
        modelContext.delete(task)
        _Concurrency.Task {
            await NotificationManager.shared.cancelNotification(taskId: task.id)
        }
        dismiss()
    }
    
    private func saveTemplate() {
        let name = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        
        let itemNames = checklistItems.sorted { $0.sortOrder < $1.sortOrder }.map { $0.name }
        
        let store: GroceryStore
        if let existing = groceryTemplates.first(where: { $0.name.lowercased() == name.lowercased() }) {
            existing.items = itemNames
            existing.updatedAt = Date()
            existing.syncStatus = SyncStatus.pending.rawValue
            store = existing
        } else {
            let created = GroceryStore(name: name, items: itemNames, syncStatus: .pending)
            modelContext.insert(created)
            store = created
        }
        _Concurrency.Task {
            await syncEngine.pushGroceryStore(store)
        }
    }
    
    private var availableTemplates: [GroceryStore] {
        groceryTemplates.filter { !$0.items.isEmpty }
    }
    
    private func loadTemplate(_ template: GroceryStore) {
        checklistItems = template.items.enumerated().map { index, name in
            ChecklistItem(id: UUID(), name: name, isChecked: false, sortOrder: index)
        }
        loadedTemplateName = template.name
        if let match = storeStore.match(template.name) {
            selectedStore = match
            updateGroceryTitle()
        }
    }
    
    private func autoSaveTemplateIfNeeded() {
        let name = loadedTemplateName ?? (selectedStore.isEmpty ? nil : selectedStore)
        guard let templateName = name else { return }
        let itemNames = checklistItems.sorted { $0.sortOrder < $1.sortOrder }.map { $0.name }
        if let existing = groceryTemplates.first(where: { $0.name.lowercased() == templateName.lowercased() }) {
            existing.items = itemNames
            existing.updatedAt = Date()
            existing.syncStatus = SyncStatus.pending.rawValue
            _Concurrency.Task {
                await syncEngine.pushGroceryStore(existing)
            }
        }
    }
    
    private func promptSaveTemplate() {
        templateName = selectedStore.isEmpty ? "My List" : selectedStore
        showSaveTemplate = true
    }
    
    private func updateTitleForCategory() {
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmedCategory.lowercased()
        let special = ["groceries", "shopping"]
        guard special.contains(lowercased) else { return }
        let currentTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if currentTitle.isEmpty || special.contains(currentTitle) || currentTitle.hasPrefix("groceries") || currentTitle.hasPrefix("shopping") {
            if selectedStore.isEmpty {
                title = trimmedCategory.isEmpty ? "" : trimmedCategory.capitalized
            } else {
                title = "\(trimmedCategory.capitalized) - \(selectedStore)"
            }
        }
    }
    
    private func updateGroceryTitle() {
        let base = category.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
        if selectedStore.isEmpty {
            title = base
        } else {
            title = "\(base) - \(selectedStore)"
        }
    }
    
    private func parseStoreFromTitle() {
        let currentTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentTitle.lowercased().hasPrefix("groceries - ") || currentTitle.lowercased().hasPrefix("shopping - ") {
            let parts = currentTitle.components(separatedBy: " - ")
            if parts.count >= 2 {
                let storePart = parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespacesAndNewlines)
                if let match = storeStore.match(storePart) {
                    selectedStore = match
                }
            }
        }
    }
    
    private var isChecklistCategory: Bool {
        let lowercased = category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lowercased == "groceries" || lowercased == "shopping"
    }
    
    private var isGroceryCategory: Bool {
        category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "groceries"
    }
    
    private func combineDateAndTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        return calendar.date(from: dateComponents) ?? date
    }
}

// MARK: - SymbolTapButton
private struct SymbolTapButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                action()
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isActive ? .blue : .secondary)
                    .symbolEffect(.bounce, value: isActive)
                Text(label)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(isActive ? .blue : .primary)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let task = Task(title: "Sample Task", priority: .high)
    return EditTaskView(task: task)
        .modelContainer(for: [Task.self, GroceryStore.self], inMemory: true)
}

private struct TemplateNameSheet: View {
    @Binding var templateName: String
    let itemCount: Int
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var isValid: Bool {
        !templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Template name", text: $templateName)
                }
                Section {
                    Text("Save these \(itemCount) items as a grocery template for next time?")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Save Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}
