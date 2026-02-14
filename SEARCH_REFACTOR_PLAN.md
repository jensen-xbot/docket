# Search Refactor Plan for Docket iOS App

## Current State

### Search Implementation
- Uses SwiftUI's native `.searchable(text: $viewModel.searchText, prompt: "Search tasks")` modifier
- Search bar appears at the top of the NavigationStack (standard iOS placement)
- Search is managed by `TaskListViewModel.searchText` property
- Filtering happens in `TaskListViewModel.filteredTasks(from:)` method

### Toolbar Layout
Current toolbar (topBarTrailing) contains:
1. Sync progress indicator
2. Notification bell with unread badge
3. Profile button
4. Mic button (`showingVoiceRecording`)
5. Plus button (`showingAddTask`)

Toolbar (topBarLeading) contains:
1. Filter menu button

## Proposed Changes

### Goal
Move search functionality from the navigation `.searchable` modifier to a dedicated search field beside the filter button in the toolbar, keeping it independent from the AI prompt functionality.

### Changes Required

#### 1. Remove `.searchable` Modifier
**File**: `TaskListView.swift`
- Remove line: `.searchable(text: $viewModel.searchText, prompt: "Search tasks")`
- This eliminates the search bar from the top of the navigation stack

#### 2. Add Search to Toolbar
**File**: `TaskListView.swift`
- Create a new `@State` property to control search bar visibility
- Add a search button/icon to the toolbar (beside filter button)
- When tapped, expand to show a search text field inline
- Show search icon with active indicator when search is active

#### 3. UI/UX Design for Toolbar Search
```
[Filter ▼] [🔍 Search...] [↻] [🔔] [👤] [🎤] [+]
           ↑ new search field
```

Or when search is active:
```
[Filter ▼] [🔍 grocery sh|] [✕] [↻] [🔔] [👤] [🎤] [+]
                          ↑ clear button
```

#### 4. State Management
- Keep using `TaskListViewModel.searchText` for the actual search query
- Add `isSearchActive` state to control visibility/focus of search field
- Maintain existing filtering logic (no changes needed there)

#### 5. Implementation Options

##### Option A: Inline Search Field (Recommended)
- Add a search text field directly in the toolbar using `ToolbarItem`
- Shows placeholder text when empty
- Shows clear button when has content
- Keyboard dismissal on scroll

##### Option B: Expandable Search
- Show search icon button
- Tap reveals search field (expands)
- Another tap or clear dismisses

### Implementation Details

#### Option A: Inline Search Field

**Advantages:**
- Always visible, easy to access
- Familiar UI pattern
- Simple implementation

**Code Structure:**
```swift
@State private var isSearchActive = false

ToolbarItem(placement: .topBarLeading) {
    HStack(spacing: 8) {
        filterMenu
        searchField
    }
}

private var searchField: some View {
    HStack(spacing: 4) {
        Image(systemName: "magnifyingglass")
            .foregroundStyle(.secondary)
            .font(.caption)
        
        TextField("Search", text: $viewModel.searchText)
            .textFieldStyle(.plain)
            .frame(width: isSearchActive ? 120 : 80)
        
        if !viewModel.searchText.isEmpty {
            Button(action: { viewModel.searchText = "" }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(Color(.systemGray6))
    .clipShape(RoundedRectangle(cornerRadius: 8))
}
```

### Testing Checklist

- [ ] Search field appears beside filter button
- [ ] Typing filters tasks correctly
- [ ] Clear button clears search text
- [ ] Empty list state shows correctly when no matches
- [ ] Filter + search work together (intersection)
- [ ] No crash or visual glitches
- [ ] Voice recording button still works
- [ ] Add task button still works
- [ ] Profile navigation still works
- [ ] Notification navigation still works
- [ ] Works on different device sizes (iPhone SE, iPhone Pro Max)

### Files to Modify
1. `/home/jensen/.openclaw/workspace/projects/docket/Docket/Docket/Views/TaskListView.swift`

### Backwards Compatibility
- No model changes
- No data migration needed
- UI-only change
- Can be reverted easily if needed

---

## Decision Log

**Decision**: Use Option A (Inline Search Field) - simpler, more accessible, follows standard iOS patterns.

**Rationale**:
- Unified AI Command Bar is not yet implemented
- Moving search to a Command Bar would couple two features that should remain independent
- Inline search in toolbar is a common iOS pattern
- Users can still quickly access search without modal interactions
