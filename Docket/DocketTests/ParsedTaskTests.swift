import XCTest
@testable import Docket

/// Tests for ParsedTask, ParseResponse, and ConfidenceLevel models
final class ParsedTaskTests: XCTestCase {
    
    // MARK: - ConfidenceLevel Tests
    
    func testConfidenceLevelRawValues() {
        XCTAssertEqual(ConfidenceLevel.high.rawValue, "high")
        XCTAssertEqual(ConfidenceLevel.medium.rawValue, "medium")
        XCTAssertEqual(ConfidenceLevel.low.rawValue, "low")
    }
    
    func testConfidenceLevelDisplayNames() {
        XCTAssertEqual(ConfidenceLevel.high.displayName, "High")
        XCTAssertEqual(ConfidenceLevel.medium.displayName, "Medium")
        XCTAssertEqual(ConfidenceLevel.low.displayName, "Low")
    }
    
    func testConfidenceLevelDefault() {
        XCTAssertEqual(ConfidenceLevel.default, .medium)
    }
    
    func testConfidenceLevelAllCases() {
        let allCases = ConfidenceLevel.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.high))
        XCTAssertTrue(allCases.contains(.medium))
        XCTAssertTrue(allCases.contains(.low))
    }
    
    func testConfidenceLevelCodable() throws {
        // Test encoding
        let highData = try JSONEncoder().encode(ConfidenceLevel.high)
        let highString = String(data: highData, encoding: .utf8)
        XCTAssertEqual(highString, "\"high\"")
        
        // Test decoding
        let mediumData = "\"medium\"".data(using: .utf8)!
        let decodedMedium = try JSONDecoder().decode(ConfidenceLevel.self, from: mediumData)
        XCTAssertEqual(decodedMedium, .medium)
    }
    
    // MARK: - ParseResponse Confidence Tests
    
    func testParseResponseWithHighConfidence() throws {
        let json = """
        {
            "type": "complete",
            "confidence": "high",
            "tasks": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440000",
                    "title": "Call mom tomorrow",
                    "priority": "medium",
                    "hasTime": false
                }
            ]
        }
        """
        
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ParseResponse.self, from: data)
        
        XCTAssertEqual(response.confidence, .high)
        XCTAssertEqual(response.effectiveConfidence, .high)
        XCTAssertTrue(response.isHighConfidence)
        XCTAssertFalse(response.isMediumConfidence)
        XCTAssertFalse(response.isLowConfidence)
    }
    
    func testParseResponseWithMediumConfidence() throws {
        let json = """
        {
            "type": "complete",
            "confidence": "medium",
            "tasks": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440001",
                    "title": "Meeting",
                    "priority": "medium",
                    "hasTime": false
                }
            ]
        }
        """
        
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ParseResponse.self, from: data)
        
        XCTAssertEqual(response.confidence, .medium)
        XCTAssertEqual(response.effectiveConfidence, .medium)
        XCTAssertFalse(response.isHighConfidence)
        XCTAssertTrue(response.isMediumConfidence)
        XCTAssertFalse(response.isLowConfidence)
    }
    
    func testParseResponseWithLowConfidence() throws {
        let json = """
        {
            "type": "question",
            "confidence": "low",
            "text": "What's the task you want to add?"
        }
        """
        
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ParseResponse.self, from: data)
        
        XCTAssertEqual(response.confidence, .low)
        XCTAssertEqual(response.effectiveConfidence, .low)
        XCTAssertFalse(response.isHighConfidence)
        XCTAssertFalse(response.isMediumConfidence)
        XCTAssertTrue(response.isLowConfidence)
    }
    
    func testParseResponseBackwardCompatibilityNoConfidence() throws {
        // Test that missing confidence field defaults to medium (backward compatibility)
        let json = """
        {
            "type": "complete",
            "tasks": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440002",
                    "title": "Old task without confidence",
                    "priority": "medium",
                    "hasTime": false
                }
            ]
        }
        """
        
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ParseResponse.self, from: data)
        
        XCTAssertNil(response.confidence)
        XCTAssertEqual(response.effectiveConfidence, .medium)
        XCTAssertFalse(response.isHighConfidence)
        XCTAssertTrue(response.isMediumConfidence) // Defaults to medium
        XCTAssertFalse(response.isLowConfidence)
    }
    
    func testParseResponseBackwardCompatibilityNullConfidence() throws {
        // Test that explicit null confidence defaults to medium
        let json = """
        {
            "type": "complete",
            "confidence": null,
            "tasks": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440003",
                    "title": "Task with null confidence",
                    "priority": "high",
                    "hasTime": false
                }
            ]
        }
        """
        
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ParseResponse.self, from: data)
        
        XCTAssertNil(response.confidence)
        XCTAssertEqual(response.effectiveConfidence, .medium)
        XCTAssertTrue(response.isMediumConfidence) // Defaults to medium
    }
    
    func testParseResponseWithAllFields() throws {
        let json = """
        {
            "type": "update",
            "confidence": "high",
            "taskId": "550e8400-e29b-41d4-a716-446655440004",
            "text": "Updated the task",
            "summary": "Task updated successfully",
            "changes": {
                "title": "Updated Title",
                "priority": "high"
            }
        }
        """
        
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ParseResponse.self, from: data)
        
        XCTAssertEqual(response.type, "update")
        XCTAssertEqual(response.confidence, .high)
        XCTAssertEqual(response.taskId, "550e8400-e29b-41d4-a716-446655440004")
        XCTAssertEqual(response.text, "Updated the task")
        XCTAssertEqual(response.summary, "Task updated successfully")
        XCTAssertNotNil(response.changes)
        XCTAssertEqual(response.changes?.title, "Updated Title")
        XCTAssertEqual(response.changes?.priority, "high")
    }
    
    func testParseResponseQuestionTypeWithConfidence() throws {
        let json = """
        {
            "type": "question",
            "confidence": "low",
            "text": "Can you clarify what you mean?"
        }
        """
        
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ParseResponse.self, from: data)
        
        XCTAssertEqual(response.type, "question")
        XCTAssertEqual(response.confidence, .low)
        XCTAssertTrue(response.isLowConfidence)
        XCTAssertEqual(response.text, "Can you clarify what you mean?")
        XCTAssertNil(response.tasks)
    }
    
    func testParseResponseDeleteTypeWithConfidence() throws {
        let json = """
        {
            "type": "delete",
            "confidence": "high",
            "taskId": "550e8400-e29b-41d4-a716-446655440005",
            "summary": "Task deleted"
        }
        """
        
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ParseResponse.self, from: data)
        
        XCTAssertEqual(response.type, "delete")
        XCTAssertEqual(response.confidence, .high)
        XCTAssertTrue(response.isHighConfidence)
        XCTAssertEqual(response.taskId, "550e8400-e29b-41d4-a716-446655440005")
    }
    
    // MARK: - Edge Cases
    
    func testParseResponseEmptyTasksWithConfidence() throws {
        let json = """
        {
            "type": "complete",
            "confidence": "medium",
            "tasks": []
        }
        """
        
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ParseResponse.self, from: data)
        
        XCTAssertEqual(response.confidence, .medium)
        XCTAssertEqual(response.tasks?.count, 0)
    }
    
    func testInvalidConfidenceValueDecoding() {
        let json = """
        {
            "type": "complete",
            "confidence": "invalid_value"
        }
        """
        
        let data = json.data(using: .utf8)!
        
        XCTAssertThrowsError(try JSONDecoder().decode(ParseResponse.self, from: data)) { error in
            guard case DecodingError.dataCorrupted(let context) = error else {
                XCTFail("Expected dataCorrupted error")
                return
            }
            XCTAssertTrue(context.debugDescription.contains("confidence"))
        }
    }
    
    func testConfidenceLevelCaseInsensitivity() {
        // Test that confidence level is case-sensitive (as per Swift enum raw values)
        let json = """
        {
            "type": "complete",
            "confidence": "HIGH"
        }
        """
        
        let data = json.data(using: .utf8)!
        
        XCTAssertThrowsError(try JSONDecoder().decode(ParseResponse.self, from: data))
    }
}
