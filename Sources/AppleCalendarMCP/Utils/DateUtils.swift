import Foundation

struct DateUtils {
    // MARK: - Formatters
    
    /// ISO8601 formatter with fractional seconds for wire format
    static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    /// Date-only formatter for YYYY-MM-DD input parsing
    static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter
    }()
    
    /// Time-only formatter for human-readable display
    static let timeOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter
    }()
    
    /// Date formatter for human-readable display
    static let humanDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter
    }()
    
    // MARK: - Parsing Helpers
    
    /// Parse a date string in YYYY-MM-DD format
    static func parseDate(_ dateString: String) throws -> Date {
        guard let date = dateOnlyFormatter.date(from: dateString) else {
            throw ValidationError.invalidDateFormat(dateString)
        }
        return date
    }
    
    /// Parse multiple date strings with validation
    static func parseDates(_ dateStrings: [String], maxCount: Int = 50) throws -> [Date] {
        guard dateStrings.count <= maxCount else {
            throw ValidationError.tooManyDates(count: dateStrings.count, maximum: maxCount)
        }
        
        return try dateStrings.map { dateString in
            let date = try parseDate(dateString)
            
            // Validate date is within reasonable range
            let now = Date()
            guard let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now),
                  let twoYearsFromNow = Calendar.current.date(byAdding: .year, value: 2, to: now) else {
                throw ValidationError.invalidDateRange(reason: "Failed to calculate date range bounds")
            }
            
            guard date >= oneYearAgo && date <= twoYearsFromNow else {
                throw ValidationError.dateOutOfRange(dateString)
            }
            
            return date
        }
    }
    
    /// Validate a date range
    static func validateDateRange(start: Date, end: Date, maxDuration: TimeInterval = 365 * 24 * 60 * 60) throws {
        guard start <= end else {
            throw ValidationError.invalidDateRange(reason: "Start date must be before or equal to end date")
        }
        
        guard end.timeIntervalSince(start) <= maxDuration else {
            let maxDays = Int(maxDuration / (24 * 60 * 60))
            throw ValidationError.invalidDateRange(reason: "Date range too large. Maximum \(maxDays) days allowed")
        }
    }
    
    // MARK: - Output Formatting
    
    /// Format event for JSON output with consistent datetime fields
    static func formatEventForOutput(_ event: EKEvent) -> [String: Any] {
        var eventDict: [String: Any] = [
            "title": event.title ?? "Untitled",
            "start_date": dateOnlyFormatter.string(from: event.startDate),
            "end_date": dateOnlyFormatter.string(from: event.endDate),
            "is_all_day": event.isAllDay,
            "calendar": event.calendar?.title ?? "Unknown",
            "start_datetime": iso8601Formatter.string(from: event.startDate),
            "end_datetime": iso8601Formatter.string(from: event.endDate)
        ]
        
        // Add human-readable times for non-all-day events
        if !event.isAllDay {
            eventDict["start_time"] = timeOnlyFormatter.string(from: event.startDate)
            eventDict["end_time"] = timeOnlyFormatter.string(from: event.endDate)
        }
        
        return eventDict
    }
    
    /// Format available slot for JSON output with ISO8601 datetimes
    static func formatSlotForOutput(_ slot: AvailableSlot) -> [String: Any] {
        return [
            "start_time": timeOnlyFormatter.string(from: slot.startTime),
            "end_time": timeOnlyFormatter.string(from: slot.endTime),
            "start_datetime": iso8601Formatter.string(from: slot.startTime),
            "end_datetime": iso8601Formatter.string(from: slot.endTime),
            "duration_minutes": slot.durationMinutes
        ]
    }
}

// MARK: - EventKit Extensions

import EventKit

extension EKEvent {
    /// Get formatted output using DateUtils
    var formattedOutput: [String: Any] {
        return DateUtils.formatEventForOutput(self)
    }
}

extension AvailableSlot {
    /// Get formatted output using DateUtils
    var formattedOutput: [String: Any] {
        return DateUtils.formatSlotForOutput(self)
    }
}