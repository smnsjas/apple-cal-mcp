import XCTest
@testable import AppleCalendarMCP

final class AppleCalendarMCPTests: XCTestCase {
    
    func testEveningHoursInitialization() {
        // Test default initialization
        let defaultHours = EveningHours()
        XCTAssertEqual(defaultHours.startHour, 17)
        XCTAssertEqual(defaultHours.startMinute, 0)
        XCTAssertEqual(defaultHours.endHour, 23)
        XCTAssertEqual(defaultHours.endMinute, 0)
        
        // Test custom initialization
        do {
            let customHours = try EveningHours(start: "18:30", end: "22:15")
            XCTAssertEqual(customHours.startHour, 18)
            XCTAssertEqual(customHours.startMinute, 30)
            XCTAssertEqual(customHours.endHour, 22)
            XCTAssertEqual(customHours.endMinute, 15)
        } catch {
            XCTFail("EveningHours initialization should not throw: \(error)")
        }
    }
    
    func testEveningHoursValidation() {
        // Test invalid time format
        XCTAssertThrowsError(try EveningHours(start: "25:00", end: "22:00")) { error in
            XCTAssertTrue(error.localizedDescription.contains("Invalid time format"))
        }
        
        // Test invalid hour values
        XCTAssertThrowsError(try EveningHours(startHour: 25, startMinute: 0, endHour: 23, endMinute: 0)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Invalid time values"))
        }
        
        // Test invalid minute values
        XCTAssertThrowsError(try EveningHours(startHour: 17, startMinute: 60, endHour: 23, endMinute: 0)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Invalid time values"))
        }
    }
    
    func testTimeTypeValues() {
        XCTAssertEqual(TimeType.evening.rawValue, "evening")
        XCTAssertEqual(TimeType.weekend.rawValue, "weekend")
        XCTAssertEqual(TimeType.allDay.rawValue, "all_day")
    }
    
    func testConflictStatusValues() {
        XCTAssertEqual(ConflictStatus.available.rawValue, "AVAILABLE")
        XCTAssertEqual(ConflictStatus.conflict.rawValue, "CONFLICT")
    }
    
    func testEventDetailTimeString() {
        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: 2025, month: 8, day: 10, hour: 14, minute: 30))!
        let endDate = calendar.date(from: DateComponents(year: 2025, month: 8, day: 10, hour: 16, minute: 0))!
        
        let event = EventDetail(
            title: "Test Meeting",
            startTime: startDate,
            endTime: endDate,
            isAllDay: false
        )
        
        XCTAssertTrue(event.timeString.contains("2:30"))
        XCTAssertTrue(event.timeString.contains("4:00"))
        
        let allDayEvent = EventDetail(
            title: "All Day Event",
            startTime: startDate,
            endTime: endDate,
            isAllDay: true
        )
        
        XCTAssertTrue(allDayEvent.timeString.contains("All day"))
    }
    
    func testAvailableSlotDurationMinutes() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(3600) // 1 hour later
        
        let slot = AvailableSlot(
            startTime: startTime,
            endTime: endTime,
            duration: 3600
        )
        
        XCTAssertEqual(slot.durationMinutes, 60)
    }
    
    func testDateRangeModel() {
        let dateRange = DateRange(start: "2025-08-10", end: "2025-08-20")
        XCTAssertEqual(dateRange.start, "2025-08-10")
        XCTAssertEqual(dateRange.end, "2025-08-20")
    }
}