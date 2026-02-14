# Task 1b: Fix Callback Signature Mismatch

## Status: IN PROGRESS

## Issue Found by QA
Critical compilation error: Callback signature mismatch between CommandBarView and TaskListView.

## Problem
**CommandBarView.onSubmit signature:**
```swift
var onSubmit: (String, @escaping (ParseResponse) -> Void) -> Void
```

**Current TaskListView.handleCommandSubmit:**
```swift
private func handleCommandSubmit(_ text: String, callback: ((Bool) -> Void)? = nil)
```

These don't match! This will cause compilation failure.

## Fix Required

Update `handleCommandSubmit` in TaskListView.swift:

```swift
private func handleCommandSubmit(
    _ text: String, 
    completion: @escaping (ParseResponse) -> Void
) {
    // TODO: Task 2 - Implement confidence flow
    print("Submitted: \(text)")
    
    // For now, return a mock response
    let mockResponse = ParseResponse(
        type: "complete",
        confidence: .medium,
        tasks: [],
        summary: "Mock response"
    )
    completion(mockResponse)
}
```

## Verification
- [ ] Signature matches CommandBarView.onSubmit
- [ ] No compilation errors
- [ ] Callback is called appropriately

## Acceptance Criteria
- TaskListView compiles without errors
- handleCommandSubmit signature matches CommandBarView expectation
