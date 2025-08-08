import XCTest
@testable import AppleCalendarMCP
import EventKit

final class ConflictAnalyzerTests: XCTestCase {
    var analyzer: ConflictAnalyzer!
    
    override func setUp() {
        super.setUp()
        analyzer = ConflictAnalyzer()
    }
    
    func testConflictSummaryGeneration() {
        let reasons = [
            ConflictReason(type: .medical, description: "Doctor appointment", severity: .high, suggestion: "Hard to reschedule"),
            ConflictReason(type: .work, description: "Team meeting", severity: .critical, suggestion: "Cannot be moved"),
            ConflictReason(type: .social, description: "Lunch", severity: .low, suggestion: "Can be moved")
        ]
        
        let summary = analyzer.generateConflictSummary(reasons)
        
        XCTAssertTrue(summary.contains("3 conflicts"))
        XCTAssertTrue(summary.contains("critical"))
    }
    
    func testEmptyConflictSummary() {
        let summary = analyzer.generateConflictSummary([])
        XCTAssertEqual(summary, "No conflicts found")
    }
}