import EventKit
import Foundation
import Logging

// MARK: - Rate Limiting Actor

/// Simple rate limiting actor to protect EventKit from burst requests
actor RateLimiter {
    private var lastRequestTime: Date = .distantPast
    private let minimumInterval: TimeInterval = 0.1  // 100ms minimum between requests

    func waitIfNeeded() async {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRequestTime)

        if elapsed < minimumInterval {
            let waitTime = minimumInterval - elapsed
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }

        lastRequestTime = Date()
    }
}

/// Manages EventKit calendar operations with rate limiting and thread safety
///
/// Provides async methods for calendar access, event querying, conflict detection,
/// and available slot finding. Includes built-in rate limiting to protect EventKit
/// from burst requests and comprehensive error handling.
final class CalendarManager {
    let eventStore = EKEventStore()
    private let logger: Logger
    private let rateLimiter = RateLimiter()

    init(logger: Logger) {
        self.logger = logger
    }

    // MARK: - EventKit Main Thread Considerations

    // EventKit operations are generally thread-safe in modern macOS/iOS versions.
    // However, if intermittent issues occur, consider marshaling EventKit access
    // to the main thread using:
    //
    // await MainActor.run {
    //     return eventStore.events(matching: predicate)
    // }
    //
    // This is typically only necessary for complex operations or when integrating
    // with UI components. The current implementation should work reliably for
    // headless MCP server usage.

    /// Requests calendar access permissions from the system
    ///
    /// Shows system permission dialog if access is not determined. Throws CalendarError
    /// if permission is denied or restricted. Call this before any calendar operations.
    ///
    /// - Throws: CalendarError.accessDenied if permission denied or restricted
    /// - Throws: CalendarError.unknownAuthorizationStatus for unexpected status
    func requestCalendarAccess() async throws {
        let authorizationStatus = EKEventStore.authorizationStatus(for: .event)

        switch authorizationStatus {
        case .authorized, .fullAccess, .writeOnly:
            logger.info("Calendar access already authorized")
            return
        case .notDetermined:
            logger.info("Requesting calendar access...")
            let granted = try await eventStore.requestAccess(to: .event)
            if !granted {
                throw CalendarError.accessDenied
            }
            logger.info("Calendar access granted")
        case .denied, .restricted:
            logger.error("Calendar access denied or restricted")
            throw CalendarError.accessDenied
        @unknown default:
            throw CalendarError.unknownAuthorizationStatus
        }
    }

    /// Retrieves calendars from EventKit, optionally filtered by names
    ///
    /// - Parameter names: Optional array of calendar names to filter by (case-sensitive)
    /// - Returns: Array of matching EKCalendar objects
    /// - Throws: No throws, but logs warning if named calendars are not found
    func getCalendars(named names: [String]? = nil) throws -> [EKCalendar] {
        let allCalendars = eventStore.calendars(for: .event)

        guard let targetNames = names else {
            return allCalendars
        }

        let filteredCalendars = allCalendars.filter { calendar in
            targetNames.contains(calendar.title)
        }

        if filteredCalendars.isEmpty {
            logger.warning("No calendars found with names: \(targetNames)")
        }

        return filteredCalendars
    }

    /// Retrieves events from calendars within the specified date range
    ///
    /// Applies rate limiting to protect EventKit from burst requests. Uses EventKit
    /// predicates for efficient server-side filtering.
    ///
    /// - Parameters:
    ///   - startDate: Start of date range (inclusive)
    ///   - endDate: End of date range (exclusive) 
    ///   - calendars: Optional array of specific calendars to query (nil = all calendars)
    /// - Returns: Array of EKEvent objects matching the criteria
    func getEvents(from startDate: Date, to endDate: Date, calendars: [EKCalendar]? = nil) async -> [EKEvent] {
        // Apply rate limiting to protect EventKit from bursts
        await rateLimiter.waitIfNeeded()

        let predicate: NSPredicate

        if let calendars = calendars {
            predicate = eventStore.predicateForEvents(
                withStart: startDate,
                end: endDate,
                calendars: calendars
            )
        } else {
            predicate = eventStore.predicateForEvents(
                withStart: startDate,
                end: endDate,
                calendars: nil
            )
        }

        return eventStore.events(matching: predicate)
    }

    func getCalendarsFromRequest(calendarNames: [String]?, calendarFilter: CalendarFilterRequest?) throws -> [EKCalendar] {
        if let filter = calendarFilter {
            return try getFilteredCalendars(filter: filter.toCalendarFilter())
        } else if let names = calendarNames {
            return try getCalendars(named: names)
        } else {
            return try getMainCalendars() // Default to main calendars instead of all
        }
    }

    /// Analyzes calendar conflicts for multiple dates and time preferences
    ///
    /// For each date, determines the appropriate time range based on timeType and checks
    /// for conflicting events. Uses ConflictAnalyzer for intelligent event classification
    /// and severity assessment.
    ///
    /// - Parameters:
    ///   - dates: Array of dates to check for conflicts
    ///   - timeType: Type of availability to check (evening/weekend/all_day)
    ///   - calendars: Calendars to query for conflicts
    ///   - eveningHours: Custom evening hour range (defaults to 17:00-23:00)
    /// - Returns: Dictionary mapping date strings (YYYY-MM-DD) to ConflictResult objects
    func checkConflicts(
        for dates: [Date],
        timeType: TimeType,
        calendars: [EKCalendar],
        eveningHours: EveningHours = EveningHours()
    ) async throws -> [String: ConflictResult] {
        var results: [String: ConflictResult] = [:]
        for date in dates {
            let dateString = DateUtils.dateOnlyFormatter.string(from: date)
            let (startTime, endTime) = try getTimeRange(for: date, timeType: timeType, eveningHours: eveningHours)

            let events = await getEvents(from: startTime, to: endTime, calendars: calendars)
            let conflictingEvents = try filterConflictingEvents(events, for: date, timeType: timeType, eveningHours: eveningHours)

            if conflictingEvents.isEmpty {
                results[dateString] = ConflictResult(
                    status: .available,
                    events: [],
                    summary: nil,
                    totalConflicts: nil,
                    conflictsByType: nil
                )
            } else {
                let analyzer = ConflictAnalyzer()
                let conflictReasons = analyzer.analyzeConflicts(conflictingEvents, for: date, timeType: timeType)

                let eventDetails = zip(conflictingEvents, conflictReasons).map { (event, reason) in
                    EventDetail(
                        title: event.title ?? "Untitled",
                        startTime: event.startDate,
                        endTime: event.endDate,
                        isAllDay: event.isAllDay,
                        conflictType: reason.type.rawValue,
                        severity: reason.severity.rawValue,
                        reason: reason.description,
                        suggestion: reason.suggestion
                    )
                }

                let summary = analyzer.generateConflictSummary(conflictReasons)
                let totalConflicts = conflictingEvents.count

                // Count conflicts by type
                let conflictsByType = Dictionary(grouping: conflictReasons, by: { $0.type.rawValue })
                    .mapValues { $0.count }

                results[dateString] = ConflictResult(
                    status: .conflict,
                    events: eventDetails,
                    summary: summary,
                    totalConflicts: totalConflicts,
                    conflictsByType: conflictsByType
                )
            }
        }

        return results
    }

    private func getTimeRange(for date: Date, timeType: TimeType, eveningHours: EveningHours) throws -> (Date, Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        switch timeType {
        case .allDay:
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                throw CalendarError.computationFailed(reason: "Failed to calculate end of day - Calendar API failure")
            }
            return (startOfDay, endOfDay)

        case .evening:
            guard let eveningStart = calendar.date(
                bySettingHour: eveningHours.startHour,
                minute: eveningHours.startMinute,
                second: 0,
                of: date
            ) else {
                throw CalendarError.computationFailed(reason: "Failed to set evening start time - Calendar API failure")
            }
            guard let eveningEnd = calendar.date(
                bySettingHour: eveningHours.endHour,
                minute: eveningHours.endMinute,
                second: 0,
                of: date
            ) else {
                throw CalendarError.computationFailed(reason: "Failed to set evening end time - Calendar API failure")
            }
            return (eveningStart, eveningEnd)

        case .weekend:
            let weekday = calendar.component(.weekday, from: date)
            if weekday == 1 || weekday == 7 || weekday == 6 { // Sunday, Saturday, or Friday
                guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                    throw CalendarError.computationFailed(reason: "Failed to calculate end of day - Calendar API failure")
                }
                return (startOfDay, endOfDay)
            } else {
                // Weekday - use evening hours
                guard let eveningStart = calendar.date(
                    bySettingHour: eveningHours.startHour,
                    minute: eveningHours.startMinute,
                    second: 0,
                    of: date
                ) else {
                    throw CalendarError.computationFailed(reason: "Failed to set evening start time - Calendar API failure")
                }
                guard let eveningEnd = calendar.date(
                    bySettingHour: eveningHours.endHour,
                    minute: eveningHours.endMinute,
                    second: 0,
                    of: date
                ) else {
                    throw CalendarError.computationFailed(reason: "Failed to set evening end time - Calendar API failure")
                }
                return (eveningStart, eveningEnd)
            }
        }
    }

    private func filterConflictingEvents(
        _ events: [EKEvent],
        for date: Date,
        timeType: TimeType,
        eveningHours: EveningHours
    ) throws -> [EKEvent] {
        _ = Calendar.current
        let (rangeStart, rangeEnd) = try getTimeRange(for: date, timeType: timeType, eveningHours: eveningHours)

        return events.filter { event in
            // Skip all-day events for evening checks unless specifically looking at all-day
            if timeType == .evening && event.isAllDay {
                return false
            }

            // Event overlaps with our time range
            return event.startDate < rangeEnd && event.endDate > rangeStart
        }
    }

    /// Finds available time slots within a date range matching duration requirements
    ///
    /// Scans each day in the range for gaps between events that meet the minimum duration.
    /// Respects time preferences (evening/weekend/all_day) when determining search windows.
    ///
    /// - Parameters:
    ///   - dateRange: Date range to search for available slots
    ///   - duration: Minimum slot duration in seconds
    ///   - timePreferences: When to look for slots (evening/weekend/all_day)
    ///   - calendars: Calendars to check for conflicts
    ///   - eveningHours: Custom evening hour range (defaults to 17:00-23:00)
    /// - Returns: Array of AvailableSlot objects representing free time periods
    func findAvailableSlots(
        in dateRange: DateInterval,
        duration: TimeInterval,
        timePreferences: TimeType,
        calendars: [EKCalendar],
        eveningHours: EveningHours = EveningHours()
    ) async throws -> [AvailableSlot] {
        var availableSlots: [AvailableSlot] = []
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: dateRange.start)

        while currentDate <= dateRange.end {
            let (dayStart, dayEnd) = try getTimeRange(for: currentDate, timeType: timePreferences, eveningHours: eveningHours)
            let events = await getEvents(from: dayStart, to: dayEnd, calendars: calendars)
            let relevantEvents = try filterConflictingEvents(events, for: currentDate, timeType: timePreferences, eveningHours: eveningHours)

            // Sort events by start time
            let sortedEvents = relevantEvents.sorted { $0.startDate < $1.startDate }

            // Find gaps between events
            var searchStart = dayStart
            for event in sortedEvents {
                let gapDuration = event.startDate.timeIntervalSince(searchStart)
                if gapDuration >= duration {
                    availableSlots.append(AvailableSlot(
                        startTime: searchStart,
                        endTime: event.startDate,
                        duration: gapDuration
                    ))
                }
                searchStart = max(searchStart, event.endDate)
            }

            // Check for slot after last event
            let finalGapDuration = dayEnd.timeIntervalSince(searchStart)
            if finalGapDuration >= duration {
                availableSlots.append(AvailableSlot(
                    startTime: searchStart,
                    endTime: dayEnd,
                    duration: finalGapDuration
                ))
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                throw CalendarError.computationFailed(reason: "Failed to increment date - Calendar API failure")
            }
            currentDate = nextDate
        }

        return availableSlots
    }
}

enum CalendarError: Error {
    case accessDenied
    case unknownAuthorizationStatus
    case calendarNotFound
    case computationFailed(reason: String)
}
