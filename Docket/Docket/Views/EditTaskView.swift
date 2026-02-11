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
                    // MARK: 1. Category & Store
                    categorySection
                    
                    // MARK: 2. Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("Task title", text: $title, axis: .vertical)
                            .font(.title3)
                            .fontDesign(.rounded)
                            .focused($titleFocused)
                    }
                    
                    Divider()
                    
                    // MARK: 3. Progress + Completed section (under title)
                    progressAndCompletedSection
                    
                    Divider()
                    
                    // MARK: 4. Checklist
                    if isChecklistCategory || !checklistItems.isEmpty {
                        ChecklistEditorView(
                            items: $checklistItems,
                            onSaveTemplate: { promptSaveTemplate() },
                            autoFocusAdd: false
                        )
                        Divider()
                    }
                    
                    // MARK: 5. Priority
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
                    }
                    
                    Divider()
                    
                    // MARK: 6. Due Date (SF Symbol tap)
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
                parseStoreFromTitle()
            }
        }
    }
    
    // MARK: - Category Section
    private var categorySection: some View {
        Group {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isEditingCategory.toggle()
                }
            } label: {
                HStack {
                    if !category.isEmpty {
                        Label {
                            HStack(spacing: 4) {
                                Text(category)
                                if !selectedStore.isEmpty {
                                    Text("·")
                                        .foregroundStyle(.secondary)
                                    Text(selectedStore)
                                }
                            }
                        } icon: {
                            Image(systemName: "tag.fill")
                                .foregroundStyle(.green)
                        }
                        .font(.subheadline)
                    } else {
                        Text("No category")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isEditingCategory ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            
            if isEditingCategory {
                CategoryPickerView(selectedCategory: $category)
                    .onChange(of: category) {
                        updateTitleForCategory()
                    }
                
                if isChecklistCategory {
                    StorePickerView(
                        selectedStore: $selectedStore,
                        onStoreChanged: { updateGroceryTitle() }
                    )
                    
                    if !availableTemplates.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Load a Template")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            FlowLayout(spacing: 8) {
                                ForEach(availableTemplates) { template in
                                    Button {
                                        loadTemplate(template)
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.caption2)
                                            Text("\(template.name) (\(template.items.count))")
                                                .font(.subheadline)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(loadedTemplateName == template.name ? Color.green.opacity(0.2) : Color(.systemGray6))
                                        .foregroundStyle(loadedTemplateName == template.name ? .green : .primary)
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(loadedTemplateName == template.name ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
                                        )
                                    }
                                }
                            }
                            
                            if let loaded = loadedTemplateName {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                    Text("Loaded: \(loaded)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
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
                    .foregroundStyle(task.isProgressEnabled ? Color.blue.opacity(0.5) : Color.gray.opacity(0.3))
                
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
                        if !hasDueDate { hasTime = false }
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
                    .transition(.opacity.combined(with: .move(edge: .top)))
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
        task.category = category.isEmpty ? nil : category
        task.notes = notes.isEmpty ? nil : notes
        task.checklistItems = checklistItems.isEmpty ? nil : checklistItems
        task.completedAt = task.isCompleted ? (task.completedAt ?? Date()) : nil
        task.updatedAt = Date()
        task.syncStatus = SyncStatus.pending.rawValue
        _Concurrency.Task {
            await NotificationManager.shared.scheduleNotification(for: task)
            await syncEngine.pushTask(task)
        }
        dismiss()
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
