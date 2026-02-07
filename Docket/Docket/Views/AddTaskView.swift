import SwiftUI
import SwiftData
import _Concurrency

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GroceryStore.name) private var groceryTemplates: [GroceryStore]
    
    @State private var title: String = ""
    @State private var priority: Priority = .medium
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = .daysFromNow(1)
    @State private var hasTime: Bool = false
    @State private var dueTime: Date = Date()
    @State private var category: String = ""
    @State private var notes: String = ""
    @State private var checklistItems: [ChecklistItem] = []
    @State private var selectedStore: String = ""
    @State private var showStorePicker: Bool = false
    @State private var loadedTemplateName: String? = nil
    
    // Save template prompt
    @State private var showSaveTemplate = false
    @State private var templateName: String = ""
    @State private var pendingTask: Task? = nil
    
    @FocusState private var titleFocused: Bool
    @FocusState private var notesFocused: Bool
    
    private let defaultStores = ["Costco", "Metro", "IGA", "Loblaws", "Maxi"]
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// All templates with items (for the chip row)
    private var availableTemplates: [GroceryStore] {
        groceryTemplates.filter { !$0.items.isEmpty }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Category (chip picker)
                    CategoryPickerView(selectedCategory: $category)
                        .onChange(of: category) {
                            updateTitleForCategory()
                            if isGroceryCategory {
                                showStorePicker = true
                            } else {
                                showStorePicker = false
                                selectedStore = ""
                            }
                        }
                    
                    // Store picker (appears when Groceries is selected)
                    if showStorePicker || isGroceryCategory {
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
                        
                        // Saved templates to load
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
                    
                    Divider()
                    
                    if isChecklistCategory {
                        ChecklistEditorView(items: $checklistItems)
                        Divider()
                    }
                    
                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("What needs to be done?", text: $title, axis: .vertical)
                            .font(.title3)
                            .focused($titleFocused)
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
            .navigationTitle("New Task")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTask() }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { titleFocused = true }
            .alert("Save as Template?", isPresented: $showSaveTemplate) {
                TextField("Template name", text: $templateName)
                Button("Save") {
                    saveTemplate()
                    finalizeSave()
                }
                Button("Skip") {
                    finalizeSave()
                }
                Button("Cancel", role: .cancel) {
                    pendingTask = nil
                }
            } message: {
                Text("Save these \(checklistItems.count) items as a grocery template for next time?")
            }
        }
    }
    
    private func loadTemplate(_ template: GroceryStore) {
        checklistItems = template.items.enumerated().map { index, name in
            ChecklistItem(id: UUID(), name: name, isChecked: false, sortOrder: index)
        }
        loadedTemplateName = template.name
        // Also set store if it matches a default store
        if defaultStores.contains(where: { $0.lowercased() == template.name.lowercased() }) {
            selectedStore = defaultStores.first(where: { $0.lowercased() == template.name.lowercased() }) ?? ""
            updateGroceryTitle()
        }
    }
    
    private func saveTask() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let finalDueDate: Date? = {
            guard hasDueDate else { return nil }
            return hasTime ? combineDateAndTime(date: dueDate, time: dueTime) : dueDate
        }()
        
        let task = Task(
            title: trimmed,
            dueDate: finalDueDate,
            hasTime: hasTime,
            priority: priority,
            category: category.isEmpty ? nil : category,
            notes: notes.isEmpty ? nil : notes,
            checklistItems: checklistItems.isEmpty ? nil : checklistItems,
            syncStatus: .pending
        )
        
        // Offer to save template if items changed
        if isChecklistCategory && !checklistItems.isEmpty && itemsDifferFromTemplate() {
            pendingTask = task
            templateName = selectedStore.isEmpty ? "My List" : selectedStore
            showSaveTemplate = true
        } else {
            modelContext.insert(task)
            _Concurrency.Task {
                await NotificationManager.shared.scheduleNotification(for: task)
            }
            dismiss()
        }
    }
    
    private func finalizeSave() {
        guard let task = pendingTask else { return }
        modelContext.insert(task)
        _Concurrency.Task {
            await NotificationManager.shared.scheduleNotification(for: task)
        }
        pendingTask = nil
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
    
    private func itemsDifferFromTemplate() -> Bool {
        let currentNames = checklistItems.sorted { $0.sortOrder < $1.sortOrder }.map { $0.name }
        for template in groceryTemplates {
            if template.items == currentNames { return false }
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
            title = trimmedCategory.isEmpty ? "" : trimmedCategory.capitalized
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
    AddTaskView()
        .modelContainer(for: [Task.self, GroceryStore.self], inMemory: true)
}
