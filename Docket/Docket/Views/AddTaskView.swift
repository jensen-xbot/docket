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
    @Environment(SyncEngine.self) private var syncEngine
    
    // Save template prompt
    @State private var showSaveTemplate = false
    @State private var templateName: String = ""
    
    @FocusState private var titleFocused: Bool
    @FocusState private var notesFocused: Bool
    
    @State private var storeStore = StoreStore()
    @AppStorage("progressTrackingDefault") private var progressTrackingDefault = false
    @State private var isProgressEnabled: Bool = false
    @State private var isRecurring: Bool = false
    @State private var recurrenceRule: String = "weekly"
    
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
                    // MARK: 1. Category (chip picker — first since it drives auto-title + checklist)
                    CategoryPickerView(selectedCategory: $category)
                        .onChange(of: category) {
                            updateTitleForCategory()
                            if isChecklistCategory {
                                showStorePicker = true
                            } else {
                                showStorePicker = false
                                selectedStore = ""
                            }
                        }
                    
                    // Store picker (appears when Groceries or Shopping is selected)
                    if showStorePicker || isChecklistCategory {
                        StorePickerView(
                            selectedStore: $selectedStore,
                            onStoreChanged: { updateGroceryTitle() }
                        )
                        
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
                    
                    // MARK: 2. Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("What needs to be done?", text: $title, axis: .vertical)
                            .font(.title3)
                            .focused($titleFocused)
                    }
                    
                    // MARK: 3. Checklist (conditional)
                    if isChecklistCategory {
                        Divider()
                        ChecklistEditorView(
                            items: $checklistItems,
                            onSaveTemplate: { promptSaveTemplate() }
                        )
                    }
                    
                    Divider()
                    
                    // MARK: 4. Priority
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
                    
                    // MARK: 5. Track Progress toggle
                    Toggle(isOn: $isProgressEnabled) {
                        Label("Track Progress", systemImage: "chart.bar.fill")
                    }
                    .tint(.blue)
                    
                    Divider()
                    
                    // MARK: 6. Due Date (matches Edit Task design)
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
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 200)
            }
            .scrollDismissesKeyboard(.immediately)
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
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .onAppear {
                titleFocused = true
                isProgressEnabled = progressTrackingDefault
            }
            .sheet(isPresented: $showSaveTemplate) {
                TemplateNameSheet(
                    templateName: $templateName,
                    itemCount: checklistItems.count,
                    onSave: { saveTemplate() },
                    onCancel: { templateName = "" }
                )
            }
        }
    }
    
    // MARK: - Due Date Section (matches Edit Task: tap calendar/clock, graphical picker)
    private var dueDateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                // Calendar icon: tap to toggle due date
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
    
    private func loadTemplate(_ template: GroceryStore) {
        checklistItems = template.items.enumerated().map { index, name in
            ChecklistItem(id: UUID(), name: name, isChecked: false, sortOrder: index)
        }
        loadedTemplateName = template.name
        // Also set store if it matches a saved store
        if let match = storeStore.match(template.name) {
            selectedStore = match
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
            syncStatus: .pending,
            isProgressEnabled: isProgressEnabled,
            recurrenceRule: hasDueDate && isRecurring ? recurrenceRule : nil
        )
        
        if isChecklistCategory && !checklistItems.isEmpty {
            autoSaveTemplateIfNeeded()
        }
        
        modelContext.insert(task)
        _Concurrency.Task {
            await NotificationManager.shared.scheduleNotification(for: task)
            await syncEngine.pushTask(task)
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

