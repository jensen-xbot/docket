# Search Refactor Plan for Docket iOS App

## Overview
Move search functionality from the default navigation `.searchable` modifier to a custom search bar positioned beside the filter button in the toolbar.

## Current State (Before Changes)

### Search Implementation
- Used SwiftUI's native `.searchable(text: $viewModel.searchText, prompt: "Search tasks")` modifier
- Search bar appeared at the top of the NavigationStack (standard iOS placement)
- Search was managed by `TaskListViewModel.searchText` property
- Filtering happened in `TaskListViewModel.filteredTasks(from:)` method

### Issues
- Search was integrated with the Unified AI Command Bar concept which was causing problems
- Search mixed with AI prompt field created UX confusion
- Need search to be independent and always accessible

## Implementation Summary

### Changes Made

#### 1. Created New SearchBar Component
**File**: `Docket/Docket/Views/SearchBar.swift`

A reusable search bar component with:
- Magnifying glass icon (left side)
- TextField for input with customizable placeholder
- Clear button (xmark.circle.fill) that appears when text is not empty
- System gray background with rounded corners
- Max width of 200 points for toolbar placement
- Smooth scale + opacity transitions for the clear button

```swift
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search"
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
            TextField(placeholder, text: $text)
            // Clear button when text not empty
        }
        .padding()
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(maxWidth: 200)
    }
}
```

#### 2. Modified TaskListView
**File**: `Docket/Docket/Views/TaskListView.swift`

**Changes**:
1. Removed `.searchable(text: $viewModel.searchText, prompt: "Search tasks")` modifier from NavigationStack
2. Added SearchBar to toolbar beside filter menu using HStack

**Before**:
```swift
@ToolbarContentBuilder
private var toolbarContent: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
        filterMenu
    }
    // ... trailing items
}

// Later in body:
.searchable(text: $viewModel.searchText, prompt: "Search tasks")
```

**After**:
```swift
@ToolbarContentBuilder
private var toolbarContent: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
        HStack(spacing: 12) {
            filterMenu
            SearchBar(text: $viewModel.searchText, placeholder: "Search")
        }
    }
    // ... trailing items
}
```

### New Toolbar Layout

```
┌────────────────────────────────────────────────────────────────┐
│ Docket                                                    Done │
├──────┬─────────────────────────┬───────────────────────────────┤
│Filter│ 🔍 Search               │ ↻  🔔  👤  🎤  +              │
│  ▼   │      ↑ new SearchBar    │sync notif prof voice add      │
└──────┴─────────────────────────┴───────────────────────────────┘
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ NavigationStack                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ TaskListView                                            │ │
│ │  ┌───────────────────────────────────────────────────┐  │ │
│ │  │ Toolbar (topBarLeading)                          │  │ │
│ │  │  ┌───────────┐    ┌───────────────────────────┐  │  │ │
│ │  │  │ FilterMenu│    │        SearchBar          │  │  │ │
│ │  │  │    ▼      │    │ ┌─────┐ ┌─────────────┐ ┌┘  │  │ │
│ │  │  └───────────┘    │ │ 🔍  │ │   Search... │ │ ✕ │  │ │
│ │  │                   │ └─────┘ └─────────────┘ └───┘  │  │ │
│ │  │                   └───────────────────────────┘  │  │ │
│ │  └───────────────────────────────────────────────────┘  │ │
│ │                                                         │ │
│ │  ┌───────────────────────────────────────────────────┐  │ │
│ │  │ TaskList (filtered by searchText + filters)      │  │ │
│ │  │                                                   │  │ │
│ │  │ • Grocery run                                     │  │ │
│ │  │ • Call mom                                        │  │ │
│ │  │ • Buy milk                                        │  │ │
│ │  │                                                   │  │ │
│ │  └───────────────────────────────────────────────────┘  │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

Search State Flow:
┌──────────────┐    ┌──────────────────┐    ┌──────────────┐
│ User types   │───▶│ viewModel.       │───▶│ filteredTasks│
│ in SearchBar │    │ searchText       │    │ (computed)   │
└──────────────┘    └──────────────────┘    └──────────────┘
                                                      │
                                                      ▼
                                              ┌──────────────┐
                                              │ Task List    │
                                              │ re-renders   │
                                              └──────────────┘
```

## State Management

No changes required to state management:
- `TaskListViewModel.searchText` still manages the search query
- `TaskListViewModel.filteredTasks(from:)` still performs filtering
- `hasActiveFilters` property already includes search text check

## Testing Checklist

- [x] Search field appears beside filter button
- [x] Typing filters tasks correctly
- [x] Clear button clears search text when visible
- [x] Empty list state shows when no matches
- [x] Filter + search work together (intersection)
- [x] Active filter indicator appears when search is active
- [x] No crash or visual glitches
- [x] Voice recording button still works
- [x] Add task button still works
- [x] Profile navigation still works
- [x] Notification navigation still works

## Benefits of This Approach

1. **Independence from AI Command Bar**: Search is now a standalone UI element, not coupled with the AI prompt functionality
2. **Always Visible**: Users can always see and access search without expanding any UI
3. **Space Efficiency**: Search doesn't take up vertical space in the task list area
4. **Familiar Pattern**: Toolbar search is a common iOS pattern (similar to Mail, Notes, etc.)
5. **Preserves Functionality**: All existing search behavior is preserved

## Branch Information

- **Branch Name**: `feature/move-search-to-toolbar`
- **Commit**: `250456e` - Move search from .searchable modifier to toolbar beside filter button
- **Files Changed**:
  - `Docket/Docket/Views/TaskListView.swift` (4 insertions, 2 deletions)
  - `Docket/Docket/Views/SearchBar.swift` (new file)

## Rollback Plan

If issues arise, simply:
1. Remove the `SearchBar` from the toolbar HStack
2. Add back `.searchable(text: $viewModel.searchText, prompt: "Search tasks")` to NavigationStack
3. Delete `SearchBar.swift` if no longer needed

---

## Implementation Complete ✅

The search refactor has been successfully implemented and pushed to the feature branch `feature/move-search-to-toolbar`. The implementation maintains full backward compatibility with the existing `TaskListViewModel` filtering logic while providing a cleaner, more accessible search UI in the toolbar.
