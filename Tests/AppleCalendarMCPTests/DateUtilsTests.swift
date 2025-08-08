import XCTest
@testable import AppleCalendarMCP

final class DateUtilsTests: XCTestCase {
    
    func testDateParsing() {
        do {
            let date = try DateUtils.parseDate("2025-08-15")
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            
            XCTAssertEqual(components.year, 2025)
            XCTAssertEqual(components.month, 8)
            XCTAssertEqual(components.day, 15)
        } catch {
            XCTFail("Valid date should parse without error: \(error)")
        }
    }
    
    func testInvalidDateParsing() {
        XCTAssertThrowsError(try DateUtils.parseDate("invalid-date")) { error in
            XCTAssertTrue(error.localizedDescription.contains("Invalid date format"))
        }
        
        XCTAssertThrowsError(try DateUtils.parseDate("2025-13-32")) { error in
            XCTAssertTrue(error.localizedDescription.contains("Invalid date format"))
        }
    }
    
    func testDateRangeValidation() {
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(3600) // 1 hour later
        
        XCTAssertNoThrow(try DateUtils.validateDateRange(start: startDate, end: endDate))
    }
    
    func testInvalidDateRangeValidation() {
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(-3600) // 1 hour earlier
        
        XCTAssertThrowsError(try DateUtils.validateDateRange(start: startDate, end: endDate)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Start date must be before"))
        }
    }
    
    func testTooManyDatesValidation() {
        let tooManyDates = Array(1...51).map { "2025-01-\(String(format: "%02d", min($0, 28)))" }
        
        XCTAssertThrowsError(try DateUtils.parseDates(tooManyDates)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Too many dates"))
        }
    }
    
    func testValidDatesArray() {
        let validDates = ["2025-08-10", "2025-08-11", "2025-08-12"]
        
        do {
            let parsedDates = try DateUtils.parseDates(validDates)
            XCTAssertEqual(parsedDates.count, 3)
        } catch {
            XCTFail("Valid dates should parse without error: \(error)")
        }
    }
    
    func testISO8601Formatting() {
        let date = Date()
        let isoString = DateUtils.iso8601Formatter.string(from: date)
        
        // Should contain T for ISO8601 format
        XCTAssertTrue(isoString.contains("T"))
        // Should contain timezone info (+ or - for offset, or Z for UTC)
        XCTAssertTrue(isoString.contains("+") || isoString.contains("-") || isoString.contains("Z"))
    }
    
    func testDateOnlyFormatting() {
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2025, month: 8, day: 15))!
        let dateString = DateUtils.dateOnlyFormatter.string(from: date)
        
        XCTAssertEqual(dateString, "2025-08-15")
    }
}