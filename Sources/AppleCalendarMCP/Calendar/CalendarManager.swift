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
        case .authorized:
            logger.info("Calendar access already authorized")
            return
        case .fullAccess:
            logger.info("Calendar full access already authorized")  
            return
        case .writeOnly:
            logger.info("Calendar write-only access authorized")
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
        // Check if we have permission - return empty if not authorized
        let authStatus = EKEventStore.authorizationStatus(for: .event)
        let isAuthorized: Bool
        if #available(macOS 14.0, *) {
            isAuthorized = authStatus == .authorized || authStatus == .fullAccess || authStatus == .writeOnly
        } else {
            isAuthorized = authStatus == .authorized
        }
        
        guard isAuthorized else {
            logger.warning("Calendar access not authorized, returning empty calendar list")
            return []
        }
        
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
        // Request permissions if needed
        do {
            try await requestCalendarAccess()
        } catch {
            logger.error("Calendar access denied: \(error)")
            return []
        }
        
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
        eveningHours: EveningHours = EveningHours(),
        eventFilter: EventFilter? = nil
    ) async throws -> [String: ConflictResult] {
        var results: [String: ConflictResult] = [:]
        for date in dates {
            let dateString = DateUtils.dateOnlyFormatter.string(from: date)
            let (startTime, endTime) = try getTimeRange(for: date, timeType: timeType, eveningHours: eveningHours)

            let events = await getEvents(from: startTime, to: endTime, calendars: calendars)
            let filteredEvents = eventFilter != nil ? self.filterEvents(events, using: eventFilter!) : events
            let conflictingEvents = try filterConflictingEvents(filteredEvents, for: date, timeType: timeType, eveningHours: eveningHours)

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
        eveningHours: EveningHours = EveningHours(),
        eventFilter: EventFilter? = nil
    ) async throws -> [AvailableSlot] {
        var availableSlots: [AvailableSlot] = []
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: dateRange.start)

        while currentDate <= dateRange.end {
            let (dayStart, dayEnd) = try getTimeRange(for: currentDate, timeType: timePreferences, eveningHours: eveningHours)
            let events = await getEvents(from: dayStart, to: dayEnd, calendars: calendars)
            let filteredEvents = eventFilter != nil ? self.filterEvents(events, using: eventFilter!) : events
            let relevantEvents = try filterConflictingEvents(filteredEvents, for: currentDate, timeType: timePreferences, eveningHours: eveningHours)

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
    
    // MARK: - Event Management
    
    /// Creates a new calendar event
    func createEvent(_ request: CreateEventRequest) async throws -> EKEvent {
        try await requestCalendarAccess()
        await rateLimiter.waitIfNeeded()
        
        // Get source event for copying if specified
        var sourceEvent: EKEvent?
        if let copyFromId = request.copyFormatFrom {
            guard let source = eventStore.event(withIdentifier: copyFromId) else {
                throw CalendarError.eventNotFound(copyFromId)
            }
            sourceEvent = source
            logger.debug("Copying format from event: \(source.title ?? "Untitled")")
        }
        
        // Determine what properties to inherit
        let defaultInherit = ["calendar", "all_day_setting", "alarm_settings"]
        let inheritProperties = request.inherit ?? defaultInherit
        
        // Find target calendar (prefer request, then source event, then default)
        let targetCalendar: EKCalendar
        if let calendarName = request.calendar {
            targetCalendar = try findCalendar(named: calendarName)
        } else if inheritProperties.contains("calendar"), let source = sourceEvent {
            targetCalendar = try source.calendar ?? findCalendar(named: nil)
        } else {
            targetCalendar = try findCalendar(named: nil)
        }
        
        // Validate calendar allows modifications
        guard targetCalendar.allowsContentModifications else {
            throw CalendarError.calendarReadOnly(targetCalendar.title)
        }
        
        // Parse dates
        let startDate = try parseISODateTime(request.startDateTime)
        var endDate = try parseISODateTime(request.endDateTime)
        
        // Handle duration inheritance
        if inheritProperties.contains("duration"), let source = sourceEvent {
            let sourceDuration = source.endDate.timeIntervalSince(source.startDate)
            endDate = startDate.addingTimeInterval(sourceDuration)
            logger.debug("Inherited duration: \(sourceDuration/60) minutes from source event")
        }
        
        guard startDate < endDate else {
            throw CalendarError.invalidDateRange(reason: "Start time must be before end time")
        }
        
        // Create event
        let event = EKEvent(eventStore: eventStore)
        event.title = request.title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = targetCalendar
        
        // Handle all-day setting (prefer request, then inheritance, then default)
        if let isAllDay = request.isAllDay {
            event.isAllDay = isAllDay
        } else if inheritProperties.contains("all_day_setting"), let source = sourceEvent {
            event.isAllDay = source.isAllDay
            logger.debug("Inherited all-day setting: \(source.isAllDay) from source event")
        } else {
            event.isAllDay = false
        }
        
        // Handle location (prefer request, then inheritance)
        if let location = request.location {
            event.location = location
        } else if inheritProperties.contains("location"), let source = sourceEvent {
            event.location = source.location
            if source.location != nil {
                logger.debug("Inherited location: \(source.location!) from source event")
            }
        }
        
        // Handle notes (prefer request, then inheritance)
        if let notes = request.notes {
            event.notes = notes
        } else if inheritProperties.contains("notes"), let source = sourceEvent {
            event.notes = source.notes
            if source.notes != nil {
                logger.debug("Inherited notes from source event")
            }
        }
        
        // Handle alarms (prefer request, then inheritance)
        if let alarmMinutes = request.alarmMinutes {
            event.alarms = alarmMinutes.map { minutes in
                EKAlarm(relativeOffset: TimeInterval(-minutes * 60))
            }
        } else if inheritProperties.contains("alarm_settings"), let source = sourceEvent, let sourceAlarms = source.alarms {
            event.alarms = sourceAlarms
            logger.debug("Inherited \(sourceAlarms.count) alarms from source event")
        }
        
        // Add recurrence rule (request only - not inherited)
        if let recurrence = request.recurrence {
            event.recurrenceRules = [try createRecurrenceRule(recurrence)]
        }
        
        // Save event
        try eventStore.save(event, span: .thisEvent)
        
        let inheritanceMsg = sourceEvent != nil ? " (copied from \(sourceEvent!.title ?? "source event"))" : ""
        logger.info("Created event: \(event.title ?? "Untitled") in calendar \(targetCalendar.title)\(inheritanceMsg)")
        
        return event
    }
    
    /// Modifies an existing calendar event
    func modifyEvent(_ request: ModifyEventRequest) async throws -> EKEvent {
        try await requestCalendarAccess()
        await rateLimiter.waitIfNeeded()
        
        // Find event by ID
        guard let event = eventStore.event(withIdentifier: request.eventId) else {
            throw CalendarError.eventNotFound(request.eventId)
        }
        
        // Check if event can be modified
        guard event.calendar.allowsContentModifications else {
            throw CalendarError.calendarReadOnly(event.calendar.title)
        }
        
        // Update fields
        if let title = request.title {
            event.title = title
        }
        
        if let startDateTime = request.startDateTime {
            event.startDate = try parseISODateTime(startDateTime)
        }
        
        if let endDateTime = request.endDateTime {
            event.endDate = try parseISODateTime(endDateTime)
        }
        
        if let location = request.location {
            event.location = location
        }
        
        if let notes = request.notes {
            event.notes = notes
        }
        
        if let isAllDay = request.isAllDay {
            event.isAllDay = isAllDay
        }
        
        // Update alarms
        if let alarmMinutes = request.alarmMinutes {
            event.alarms = alarmMinutes.map { minutes in
                EKAlarm(relativeOffset: TimeInterval(-minutes * 60))
            }
        }
        
        // Move to different calendar if requested
        if let moveToCalendar = request.moveToCalendar {
            let targetCalendar = try findCalendar(named: moveToCalendar)
            guard targetCalendar.allowsContentModifications else {
                throw CalendarError.calendarReadOnly(targetCalendar.title)
            }
            event.calendar = targetCalendar
        }
        
        // Validate date range
        guard event.startDate < event.endDate else {
            throw CalendarError.invalidDateRange(reason: "Start time must be before end time")
        }
        
        // Save changes
        try eventStore.save(event, span: .thisEvent)
        logger.info("Modified event: \(event.title ?? "Untitled")")
        
        return event
    }
    
    /// Deletes a calendar event
    func deleteEvent(_ request: DeleteEventRequest) async throws -> Bool {
        try await requestCalendarAccess()
        await rateLimiter.waitIfNeeded()
        
        // Find event by ID
        guard let event = eventStore.event(withIdentifier: request.eventId) else {
            throw CalendarError.eventNotFound(request.eventId)
        }
        
        // Check if event can be deleted
        guard event.calendar.allowsContentModifications else {
            throw CalendarError.calendarReadOnly(event.calendar.title)
        }
        
        // Determine span for recurring events
        let span: EKSpan
        if let deleteOption = request.deleteRecurring {
            switch deleteOption {
            case .thisOnly:
                span = .thisEvent
            case .thisAndFuture:
                span = .futureEvents
            case .all:
                span = .futureEvents // EventKit doesn't have "all", use futureEvents for recurring
            }
        } else {
            span = .thisEvent
        }
        
        // Delete event
        try eventStore.remove(event, span: span)
        logger.info("Deleted event: \(event.title ?? "Untitled")")
        
        return true
    }
    
    // MARK: - Helper Methods
    
    private func findCalendar(named name: String?) throws -> EKCalendar {
        let allCalendars = eventStore.calendars(for: .event)
        
        if let targetName = name {
            // Look for specific calendar by name
            guard let calendar = allCalendars.first(where: { $0.title == targetName }) else {
                logger.error("Calendar '\(targetName)' not found. Available calendars: \(allCalendars.map { $0.title })")
                throw CalendarError.calendarNotFound(targetName)
            }
            return calendar
        } else {
            // Find first writable calendar as default
            let writableCalendars = allCalendars.filter { $0.allowsContentModifications }
            
            logger.debug("Looking for default writable calendar. Found \(writableCalendars.count) writable calendars: \(writableCalendars.map { $0.title })")
            
            guard let defaultCalendar = writableCalendars.first else {
                logger.error("No writable calendars found. Available calendars: \(allCalendars.map { "\($0.title) (writable: \($0.allowsContentModifications))" })")
                throw CalendarError.calendarNotFound("No writable calendar available")
            }
            
            logger.info("Using default writable calendar: \(defaultCalendar.title)")
            return defaultCalendar
        }
    }
    
    private func parseISODateTime(_ dateString: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        
        // Try different ISO8601 format combinations
        let formatOptions: [ISO8601DateFormatter.Options] = [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime],
            [.withFullDate, .withTime, .withTimeZone],
            [.withFullDate, .withTime],
            [.withFullDate, .withDashSeparatorInDate, .withTime, .withColonSeparatorInTime],
        ]
        
        for options in formatOptions {
            formatter.formatOptions = options
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        // Try manual parsing for local datetime format (YYYY-MM-DDTHH:mm:ss)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = TimeZone.current
        if let date = dateFormatter.date(from: dateString) {
            return date
        }
        
        // Try with fractional seconds
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        if let date = dateFormatter.date(from: dateString) {
            return date
        }
        
        throw CalendarError.invalidDateTimeFormat(dateString)
    }
    
    private func createRecurrenceRule(_ rule: RecurrenceRule) throws -> EKRecurrenceRule {
        let frequency: EKRecurrenceFrequency
        switch rule.frequency {
        case .daily:
            frequency = .daily
        case .weekly:
            frequency = .weekly
        case .monthly:
            frequency = .monthly
        case .yearly:
            frequency = .yearly
        }
        
        let interval = rule.interval ?? 1
        
        // End condition
        let end: EKRecurrenceEnd?
        if let count = rule.count {
            end = EKRecurrenceEnd(occurrenceCount: count)
        } else if let until = rule.until {
            let untilDate = try parseISODateTime(until)
            end = EKRecurrenceEnd(end: untilDate)
        } else {
            end = nil
        }
        
        // Days of week (for weekly recurrence)
        var daysOfWeek: [EKRecurrenceDayOfWeek]?
        if let days = rule.daysOfWeek {
            daysOfWeek = days.compactMap { dayNum in
                if let ekDay = EKWeekday(rawValue: dayNum) {
                    return EKRecurrenceDayOfWeek(ekDay)
                }
                return nil
            }
        }
        
        return EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            daysOfTheWeek: daysOfWeek,
            daysOfTheMonth: nil,
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: end
        )
    }
}

enum CalendarError: Error, LocalizedError {
    case accessDenied
    case unknownAuthorizationStatus
    case calendarNotFound(String)
    case calendarReadOnly(String)
    case eventNotFound(String)
    case invalidDateTimeFormat(String)
    case computationFailed(reason: String)
    case invalidDateRange(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access denied. Please grant calendar permissions."
        case .unknownAuthorizationStatus:
            return "Unknown calendar authorization status."
        case .calendarNotFound(let name):
            return "Calendar '\(name)' not found."
        case .calendarReadOnly(let name):
            return "Calendar '\(name)' is read-only and cannot be modified."
        case .eventNotFound(let id):
            return "Event with ID '\(id)' not found."
        case .invalidDateTimeFormat(let format):
            return "Invalid date/time format: '\(format)'. Expected ISO8601 format."
        case .computationFailed(let reason):
            return "Calendar computation failed: \(reason)"
        case .invalidDateRange(let reason):
            return "Invalid date range: \(reason)"
        }
    }
}
