import SwiftUI
import SwiftData
import _Concurrency

struct EditTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
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
    @State private var pendingSave = false
    
    @FocusState private var titleFocused: Bool
    @FocusState private var notesFocused: Bool
    
    private let defaultStores = ["Costco", "Metro", "IGA", "Loblaws", "Maxi"]
    
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
                    // Category & Store — collapsed or expanded
                    if isEditingCategory {
                        CategoryPickerView(selectedCategory: $category)
                            .onChange(of: category) {
                                updateTitleForCategory()
                            }
                        
                        if isGroceryCategory {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Store")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                FlowLayout(spacing: 8) {
                                    ForEach(defaultStores, id: \.self) { store in
                                        Button {
                                            if selectedStore == store {
                                                selectedStore = ""
                                            } else {
                                                selectedStore = store
                                            }
                                            updateGroceryTitle()
                                        } label: {
                                            Text(store)
                                                .font(.subheadline)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(selectedStore == store ? Color.orange : Color(.systemGray6))
                                                .foregroundStyle(selectedStore == store ? .white : .primary)
                                                .cornerRadius(16)
                                        }
                                    }
                                }
                            }
                            
                            // Saved templates
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
                        
                        Button("Done") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isEditingCategory = false
                            }
                        }
                        .font(.subheadline)
                    } else {
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
                            
                            Button("Edit") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isEditingCategory = true
                                }
                            }
                            .font(.subheadline)
                        }
                    }
                    
                    Divider()
                    
                    if isChecklistCategory || !checklistItems.isEmpty {
                        ChecklistEditorView(items: $checklistItems)
                        Divider()
                    }
                    
                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("Task title", text: $title, axis: .vertical)
                            .font(.title3)
                            .focused($titleFocused)
                    }
                    
                    Divider()
                    
                    // Completed toggle
                    Toggle(isOn: $task.isCompleted) {
                        Label("Completed", systemImage: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    }
                    
                    Divider()
                    
                    // Priority
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
                    
                    // Due Date
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $hasDueDate.animation(.easeInOut(duration: 0.2))) {
                            Label("Due Date", systemImage: "calendar")
                                .font(.subheadline)
                        }
                        .onChange(of: hasDueDate) {
                            if !hasDueDate { hasTime = false }
                        }
                        if hasDueDate {
                            DatePicker("", selection: $dueDate, displayedComponents: [.date])
                                .datePickerStyle(.graphical)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            
                            Toggle(isOn: $hasTime.animation(.easeInOut(duration: 0.2))) {
                                Label("Set Time", systemImage: "clock")
                                    .font(.subheadline)
                            }
                            
                            if hasTime {
                                DatePicker("", selection: $dueTime, displayedComponents: [.hourAndMinute])
                                    .datePickerStyle(.compact)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("Add any extra details...", text: $notes, axis: .vertical)
                            .lineLimit(3...8)
                            .focused($notesFocused)
                    }
                    
                    Divider()
                    
                    // Delete
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
            .onTapGesture {
                titleFocused = false
                notesFocused = false
            }
            .scrollDismissesKeyboard(.interactively)
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
            }
            .confirmationDialog("Delete this task?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deleteTask() }
                Button("Cancel", role: .cancel) { }
            }
            .alert("Save as Template?", isPresented: $showSaveTemplate) {
                TextField("Template name", text: $templateName)
                Button("Save") {
                    saveTemplate()
                    finalizeUpdate()
                }
                Button("Skip") {
                    finalizeUpdate()
                }
                Button("Cancel", role: .cancel) {
                    pendingSave = false
                }
            } message: {
                Text("Save these \(checklistItems.count) items as a grocery template for next time?")
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
    
    private func updateTask() {
        // Check if we should offer to save template
        if isChecklistCategory && !checklistItems.isEmpty && itemsDifferFromTemplate() {
            pendingSave = true
            templateName = selectedStore.isEmpty ? "My List" : selectedStore
            showSaveTemplate = true
        } else {
            finalizeUpdate()
        }
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
        }
        pendingSave = false
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
        
        if let existing = groceryTemplates.first(where: { $0.name.lowercased() == name.lowercased() }) {
            existing.items = itemNames
            existing.updatedAt = Date()
        } else {
            let store = GroceryStore(name: name, items: itemNames)
            modelContext.insert(store)
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
        if defaultStores.contains(where: { $0.lowercased() == template.name.lowercased() }) {
            selectedStore = defaultStores.first(where: { $0.lowercased() == template.name.lowercased() }) ?? ""
            updateGroceryTitle()
        }
    }
    
    private func itemsDifferFromTemplate() -> Bool {
        let currentNames = checklistItems.sorted { $0.sortOrder < $1.sortOrder }.map { $0.name }
        for template in groceryTemplates {
            if template.items == currentNames {
                return false
            }
        }
        return true
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
                if defaultStores.contains(where: { $0.lowercased() == storePart.lowercased() }) {
                    selectedStore = defaultStores.first(where: { $0.lowercased() == storePart.lowercased() }) ?? ""
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

#Preview {
    let task = Task(title: "Sample Task", priority: .high)
    return EditTaskView(task: task)
        .modelContainer(for: [Task.self, GroceryStore.self], inMemory: true)
}
