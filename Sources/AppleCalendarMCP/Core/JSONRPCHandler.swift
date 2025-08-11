import EventKit
import Foundation
import Logging

/// Handles MCP JSON-RPC 2.0 protocol communication over stdin/stdout
///
/// Processes MCP requests including initialize, tools/list, and tools/call methods.
/// Provides correlated logging with request IDs and integrates with CalendarManager
/// for calendar operations. All responses follow MCP content format specification.
final class JSONRPCHandler {
    private let calendarManager: CalendarManager
    private let logger: Logger
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(calendarManager: CalendarManager, logger: Logger) {
        self.calendarManager = calendarManager
        self.logger = logger

        // Configure ISO8601 date formatting using centralized DateUtils
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    /// Processes a complete MCP JSON-RPC request and returns encoded response
    ///
    /// Handles all MCP protocol methods with comprehensive error handling and logging.
    /// Request/response correlation is maintained through request IDs in log metadata.
    ///
    /// - Parameter data: Raw JSON-RPC request data
    /// - Returns: Encoded JSON-RPC response data
    func handleRequest(_ data: Data) async -> Data {
        do {
            let request = try decoder.decode(MCPRequest.self, from: data)

            // Create correlated logging metadata with request ID and method
            let requestIdString = request.id.map { "\($0.value)" } ?? "null"
            let metadata: Logger.Metadata = [
                "requestId": "\(requestIdString)",
                "method": "\(request.method)"
            ]

            logger.debug("Processing request", metadata: metadata)

            let response: MCPResponse

            switch request.method {
            case "initialize":
                response = handleInitialize(request: request)
            case "tools/list":
                response = handleToolsList(request: request)
            case "tools/call":
                response = await handleToolCall(request: request)
            case "prompts/list":
                response = handlePromptsList(request: request)
            case "resources/list":
                response = handleResourcesList(request: request)
            default:
                response = MCPResponse(
                    id: request.id,
                    error: MCPError(code: -32601, message: "Method not found", data: nil)
                )
            }

            logger.debug("Request completed successfully", metadata: metadata)
            return try encoder.encode(response)
        } catch {
            // For parse errors, we don't have request metadata
            logger.error("Error handling request: \(error)")
            let errorResponse = createErrorResponse(id: nil, error: MCPError.parseError("Parse error: \(error.localizedDescription)"))

            do {
                return try encoder.encode(errorResponse)
            } catch {
                logger.error("Failed to encode error response: \(error)")
                return Data()
            }
        }
    }

    func createErrorResponse(id: MCPRequestID?, error: MCPError) -> MCPResponse {
        // Ensure we never send null ID - use a default ID for parse errors
        let responseId = id ?? AnyCodable("error")
        return MCPResponse(id: responseId, error: error)
    }

    private func handleInitialize(request: MCPRequest) -> MCPResponse {
        let result: [String: Any] = [
            "protocolVersion": "2025-06-18",
            "capabilities": [
                "tools": [:]
            ],
            "serverInfo": [
                "name": "apple-cal-mcp",
                "version": "1.0.0"
            ]
        ]

        return MCPResponse(id: request.id, result: result)
    }

    private func handlePromptsList(request: MCPRequest) -> MCPResponse {
        // Return empty prompts list since we don't provide any prompts
        return MCPResponse(id: request.id, result: ["prompts": []])
    }
    
    private func handleResourcesList(request: MCPRequest) -> MCPResponse {
        // Return empty resources list since we don't provide any resources
        return MCPResponse(id: request.id, result: ["resources": []])
    }

    private func handleToolsList(request: MCPRequest) -> MCPResponse {
        let tools: [[String: Any]] = [
            [
                "name": "list_calendars",
                "description": "List and filter available calendars",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "calendar_filter": [
                            "type": "object",
                            "properties": [
                                "include_names": [
                                    "type": "array",
                                    "items": ["type": "string"],
                                    "description": "Only include calendars with these names"
                                ],
                                "exclude_names": [
                                    "type": "array",
                                    "items": ["type": "string"],
                                    "description": "Exclude calendars with these names"
                                ],
                                "include_accounts": [
                                    "type": "array",
                                    "items": ["type": "string"],
                                    "description": "Only include calendars from these accounts (Exchange, iCloud, etc.)"
                                ],
                                "exclude_accounts": [
                                    "type": "array",
                                    "items": ["type": "string"],
                                    "description": "Exclude calendars from these accounts"
                                ],
                                "exclude_holidays": [
                                    "type": "boolean",
                                    "description": "Exclude holiday and birthday calendars"
                                ],
                                "exclude_sports": [
                                    "type": "boolean",
                                    "description": "Exclude sports team calendars"
                                ],
                                "exclude_subscribed": [
                                    "type": "boolean",
                                    "description": "Exclude subscribed calendars"
                                ],
                                "exclude_read_only": [
                                    "type": "boolean",
                                    "description": "Exclude read-only calendars"
                                ],
                                "preset": [
                                    "type": "string", 
                                    "enum": ["work", "personal", "main", "all", "clean", "debug"],
                                    "description": "Quick filter presets: 'work' (Work calendars only), 'personal' (Personal calendars), 'main' (Core calendars), 'all' (No filters), 'clean' (Exclude subscribed/holidays/sports), 'debug' (Show everything for troubleshooting)"
                                ]
                            ]
                        ]
                    ]
                ]
            ],
            [
                "name": "check_calendar_conflicts",
                "description": "Check multiple dates for calendar conflicts based on time preferences. Tip: Use calendar_filter presets but avoid restrictive event_filter to ensure all conflicts are found.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "dates": [
                            "type": "array",
                            "items": ["type": "string"],
                            "description": "Array of dates in YYYY-MM-DD format"
                        ],
                        "time_type": [
                            "type": "string",
                            "enum": ["evening", "weekend", "all_day"],
                            "description": "Type of time availability to check"
                        ],
                        "calendar_names": [
                            "type": "array",
                            "items": ["type": "string"],
                            "description": "Optional array of specific calendar names to check"
                        ],
                        "calendar_filter": [
                            "type": "object",
                            "description": "Advanced filtering options for calendars (same schema as list_calendars)"
                        ],
                        "event_filter": [
                            "type": "object",
                            "properties": [
                                "exclude_all_day": ["type": "boolean", "description": "Exclude all-day events"],
                                "exclude_busy": ["type": "boolean", "description": "Exclude busy events"],
                                "exclude_tentative": ["type": "boolean", "description": "Exclude tentative events"],
                                "exclude_private": ["type": "boolean", "description": "Exclude private events"],
                                "title_contains": ["type": "array", "items": ["type": "string"], "description": "Only include events with titles containing these keywords (ignored if work_meetings_only is true)"],
                                "title_excludes": ["type": "array", "items": ["type": "string"], "description": "Exclude events with titles containing these keywords"],
                                "minimum_duration_minutes": ["type": "number", "description": "Minimum event duration in minutes"],
                                "maximum_duration_minutes": ["type": "number", "description": "Maximum event duration in minutes"],
                                "work_meetings_only": ["type": "boolean", "description": "Smart work meeting detection using time, duration, calendar type, and content heuristics (recommended over title_contains)"],
                                "business_hours_only": ["type": "boolean", "description": "Only include events during business hours (8 AM - 6 PM)"]
                            ]
                        ],
                        "evening_hours": [
                            "type": "object",
                            "properties": [
                                "start": ["type": "string", "description": "Start time in HH:mm format"],
                                "end": ["type": "string", "description": "End time in HH:mm format"]
                            ]
                        ]
                    ],
                    "required": ["dates", "time_type"]
                ]
            ],
            [
                "name": "get_calendar_events",
                "description": "Get all events in a specified date range. Tip: Start without event_filter to see all events, then filter if needed to avoid missing important meetings.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "start_date": [
                            "type": "string",
                            "description": "Start date in YYYY-MM-DD format"
                        ],
                        "end_date": [
                            "type": "string",
                            "description": "End date in YYYY-MM-DD format"
                        ],
                        "calendar_names": [
                            "type": "array",
                            "items": ["type": "string"],
                            "description": "Optional array of specific calendar names"
                        ],
                        "calendar_filter": [
                            "type": "object",
                            "description": "Advanced filtering options for calendars (same schema as list_calendars)"
                        ],
                        "event_filter": [
                            "type": "object",
                            "description": "Filtering options for events (same schema as check_calendar_conflicts)"
                        ]
                    ],
                    "required": ["start_date", "end_date"]
                ]
            ],
            [
                "name": "find_available_slots",
                "description": "Find available time slots matching specified criteria",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "date_range": [
                            "type": "object",
                            "properties": [
                                "start": ["type": "string", "description": "Start date in YYYY-MM-DD format"],
                                "end": ["type": "string", "description": "End date in YYYY-MM-DD format"]
                            ],
                            "required": ["start", "end"]
                        ],
                        "duration_minutes": [
                            "type": "integer",
                            "description": "Minimum duration in minutes"
                        ],
                        "time_preferences": [
                            "type": "string",
                            "enum": ["evening", "weekend", "all_day"],
                            "description": "Time preference for available slots"
                        ],
                        "calendar_names": [
                            "type": "array",
                            "items": ["type": "string"],
                            "description": "Optional array of specific calendar names"
                        ],
                        "calendar_filter": [
                            "type": "object",
                            "description": "Advanced filtering options for calendars (same schema as list_calendars)"
                        ],
                        "event_filter": [
                            "type": "object",
                            "description": "Filtering options for events (same schema as check_calendar_conflicts)"
                        ],
                        "evening_hours": [
                            "type": "object",
                            "properties": [
                                "start": ["type": "string", "description": "Start time in HH:mm format"],
                                "end": ["type": "string", "description": "End time in HH:mm format"]
                            ]
                        ]
                    ],
                    "required": ["date_range", "duration_minutes", "time_preferences"]
                ]
            ],
            [
                "name": "create_event",
                "description": "Create a new calendar event with full details including location, attendees, and recurrence. Can copy properties from an existing event.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "title": [
                            "type": "string",
                            "description": "Event title"
                        ],
                        "start_datetime": [
                            "type": "string",
                            "description": "Start date and time in ISO8601 format (e.g., 2025-08-15T14:30:00)"
                        ],
                        "end_datetime": [
                            "type": "string", 
                            "description": "End date and time in ISO8601 format"
                        ],
                        "calendar": [
                            "type": "string",
                            "description": "Calendar name (optional, defaults to primary calendar or copied from source event)"
                        ],
                        "location": [
                            "type": "string",
                            "description": "Event location"
                        ],
                        "notes": [
                            "type": "string",
                            "description": "Event notes/description"
                        ],
                        "is_all_day": [
                            "type": "boolean",
                            "description": "Whether this is an all-day event"
                        ],
                        "attendees": [
                            "type": "array",
                            "items": ["type": "string"],
                            "description": "List of attendee email addresses"
                        ],
                        "alarm_minutes": [
                            "type": "array",
                            "items": ["type": "integer"],
                            "description": "Alert times in minutes before event (e.g., [15, 60] for 15min and 1hr alerts)"
                        ],
                        "recurrence": [
                            "type": "object",
                            "properties": [
                                "frequency": [
                                    "type": "string",
                                    "enum": ["daily", "weekly", "monthly", "yearly"],
                                    "description": "How often the event repeats"
                                ],
                                "interval": ["type": "integer", "description": "Repeat every N periods (e.g., every 2 weeks)"],
                                "count": ["type": "integer", "description": "Number of occurrences"],
                                "until": ["type": "string", "description": "End date in ISO8601 format"],
                                "days_of_week": [
                                    "type": "array", 
                                    "items": ["type": "integer"],
                                    "description": "Days of week for weekly recurrence (1=Sunday, 2=Monday, etc.)"
                                ]
                            ],
                            "required": ["frequency"]
                        ],
                        "copy_format_from": [
                            "type": "string",
                            "description": "Event ID to copy properties from (calendar, duration, alarms, all-day setting, etc.)"
                        ],
                        "inherit": [
                            "type": "array",
                            "items": ["type": "string"],
                            "enum": [["calendar", "all_day_setting", "duration", "alarm_settings", "location", "notes"]],
                            "description": "Properties to inherit from source event. Options: calendar, all_day_setting, duration, alarm_settings, location, notes. If not specified, inherits calendar, all_day_setting, and alarm_settings by default."
                        ]
                    ],
                    "required": ["title", "start_datetime", "end_datetime"]
                ]
            ],
            [
                "name": "modify_event",
                "description": "Modify an existing calendar event. Only specified fields will be updated.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "event_id": [
                            "type": "string",
                            "description": "Unique identifier of the event to modify"
                        ],
                        "title": ["type": "string", "description": "New event title"],
                        "start_datetime": ["type": "string", "description": "New start time in ISO8601 format"],
                        "end_datetime": ["type": "string", "description": "New end time in ISO8601 format"],
                        "location": ["type": "string", "description": "New location"],
                        "notes": ["type": "string", "description": "New notes/description"],
                        "is_all_day": ["type": "boolean", "description": "Change all-day status"],
                        "attendees": [
                            "type": "array",
                            "items": ["type": "string"],
                            "description": "New attendee list (replaces existing)"
                        ],
                        "alarm_minutes": [
                            "type": "array", 
                            "items": ["type": "integer"],
                            "description": "New alert times (replaces existing)"
                        ],
                        "move_to_calendar": [
                            "type": "string",
                            "description": "Move event to a different calendar"
                        ]
                    ],
                    "required": ["event_id"]
                ]
            ],
            [
                "name": "delete_event",
                "description": "Delete a calendar event. Supports recurring event options.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "event_id": [
                            "type": "string",
                            "description": "Unique identifier of the event to delete"
                        ],
                        "delete_recurring": [
                            "type": "string",
                            "enum": ["this_only", "this_and_future", "all"],
                            "description": "For recurring events: delete this occurrence, this and future, or all occurrences"
                        ]
                    ],
                    "required": ["event_id"]
                ]
            ]
        ]

        return MCPResponse(id: request.id, result: ["tools": tools])
    }

    private func handleToolCall(request: MCPRequest) async -> MCPResponse {
        guard let params = request.getParams(),
              let name = params["name"] as? String,
              let arguments = params["arguments"] as? [String: Any] else {
            return MCPResponse(
                id: request.id,
                error: MCPError(code: -32602, message: "Invalid parameters", data: nil)
            )
        }

        // Create tool-specific logging metadata
        let requestIdString = request.id.map { "\($0.value)" } ?? "null"
        let metadata: Logger.Metadata = [
            "requestId": "\(requestIdString)",
            "method": "tools/call",
            "tool": "\(name)"
        ]

        logger.debug("Processing tool call", metadata: metadata)

        do {
            let result: [String: Any]

            switch name {
            case "check_calendar_conflicts":
                result = try await handleCheckConflicts(arguments: arguments)
            case "get_calendar_events":
                result = try await handleGetEvents(arguments: arguments)
            case "find_available_slots":
                result = try await handleFindSlots(arguments: arguments)
            case "list_calendars":
                result = try await handleListCalendars(arguments: arguments)
            case "create_event":
                result = try await handleCreateEvent(arguments: arguments)
            case "modify_event":
                result = try await handleModifyEvent(arguments: arguments)
            case "delete_event":
                result = try await handleDeleteEvent(arguments: arguments)
            default:
                return MCPResponse(
                    id: request.id,
                    error: MCPError(code: -32602, message: "Unknown tool", data: nil)
                )
            }

            logger.debug("Tool call completed successfully", metadata: metadata)
            return MCPResponse(id: request.id, result: ["content": [["type": "text", "text": try String(data: JSONSerialization.data(withJSONObject: result, options: .prettyPrinted), encoding: .utf8) ?? ""]]])
        } catch {
            logger.error("Error handling tool call: \(error)", metadata: metadata)
            
            // Provide more specific error messages for CalendarError
            if let calendarError = error as? CalendarError {
                return MCPResponse(
                    id: request.id,
                    error: MCPError(code: -32603, message: calendarError.errorDescription ?? "Calendar error", data: ["error_type": String(describing: calendarError)])
                )
            }
            
            return MCPResponse(
                id: request.id,
                error: MCPError(code: -32603, message: "Internal error", data: ["details": error.localizedDescription])
            )
        }
    }

    private func handleCheckConflicts(arguments: [String: Any]) async throws -> [String: Any] {
        let argumentsData = try JSONSerialization.data(withJSONObject: arguments)
        let request = try decoder.decode(CheckConflictsRequest.self, from: argumentsData)

        let dates = try DateUtils.parseDates(request.dates)

        let calendars = try calendarManager.getCalendarsFromRequest(
            calendarNames: request.calendarNames,
            calendarFilter: request.calendarFilter
        )
        let eveningHours = request.eveningHours ?? EveningHours()

        let conflicts = try await calendarManager.checkConflicts(
            for: dates,
            timeType: request.timeType,
            calendars: calendars,
            eveningHours: eveningHours,
            eventFilter: request.eventFilter?.toEventFilter()
        )

        var result: [String: Any] = [:]
        for (dateString, conflictResult) in conflicts {
            var eventData: [[String: Any]] = []
            for event in conflictResult.events {
                var eventDict: [String: Any] = [
                    "title": event.title,
                    "time": event.timeString,
                    "is_all_day": event.isAllDay
                ]

                if let conflictType = event.conflictType {
                    eventDict["conflict_type"] = conflictType
                }

                if let severity = event.severity {
                    eventDict["severity"] = severity
                }

                if let reason = event.reason {
                    eventDict["reason"] = reason
                }

                if let suggestion = event.suggestion {
                    eventDict["suggestion"] = suggestion
                }

                eventData.append(eventDict)
            }

            var dateResult: [String: Any] = [
                "status": conflictResult.status.rawValue,
                "events": eventData
            ]

            if let summary = conflictResult.summary {
                dateResult["summary"] = summary
            }

            if let totalConflicts = conflictResult.totalConflicts {
                dateResult["total_conflicts"] = totalConflicts
            }

            if let conflictsByType = conflictResult.conflictsByType {
                dateResult["conflicts_by_type"] = conflictsByType
            }

            result[dateString] = dateResult
        }

        return result
    }

    private func handleGetEvents(arguments: [String: Any]) async throws -> [String: Any] {
        let argumentsData = try JSONSerialization.data(withJSONObject: arguments)
        let request = try decoder.decode(GetEventsRequest.self, from: argumentsData)

        let startDate = try DateUtils.parseDate(request.startDate)
        let parsedEndDate = try DateUtils.parseDate(request.endDate)

        try DateUtils.validateDateRange(start: startDate, end: parsedEndDate)
        
        // Fix EventKit issue: For same-day queries, end date must be next day
        // EventKit uses exclusive end dates, so 2025-08-15 to 2025-08-15 returns nothing
        let endDate: Date
        if Calendar.current.isDate(startDate, inSameDayAs: parsedEndDate) {
            // Single day query - extend end date to next day for EventKit
            endDate = Calendar.current.date(byAdding: .day, value: 1, to: parsedEndDate) ?? parsedEndDate
            logger.debug("Single-day query detected: \(request.startDate) -> querying \(startDate) to \(endDate)")
        } else {
            // Multi-day query - use as-is but ensure end date is start of next day
            endDate = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: parsedEndDate) ?? parsedEndDate)
            logger.debug("Multi-day query: \(request.startDate) to \(request.endDate) -> querying \(startDate) to \(endDate)")
        }

        let calendars = try calendarManager.getCalendarsFromRequest(
            calendarNames: request.calendarNames,
            calendarFilter: request.calendarFilter
        )
        let events = await calendarManager.getEvents(from: startDate, to: endDate, calendars: calendars)
        let filteredEvents = request.eventFilter != nil ? calendarManager.filterEvents(events, using: request.eventFilter!.toEventFilter()) : events

        let eventData = filteredEvents.map { $0.formattedOutput }

        return ["events": eventData]
    }

    private func handleFindSlots(arguments: [String: Any]) async throws -> [String: Any] {
        let argumentsData = try JSONSerialization.data(withJSONObject: arguments)
        let request = try decoder.decode(FindSlotsRequest.self, from: argumentsData)

        let startDate = try DateUtils.parseDate(request.dateRange.start)
        let parsedEndDate = try DateUtils.parseDate(request.dateRange.end)

        try DateUtils.validateDateRange(start: startDate, end: parsedEndDate)
        
        // Fix EventKit issue: For same-day queries, extend end date to next day
        let endDate: Date
        if Calendar.current.isDate(startDate, inSameDayAs: parsedEndDate) {
            endDate = Calendar.current.date(byAdding: .day, value: 1, to: parsedEndDate) ?? parsedEndDate
            logger.debug("Single-day slot query: \(request.dateRange.start) -> querying \(startDate) to \(endDate)")
        } else {
            endDate = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: parsedEndDate) ?? parsedEndDate)
            logger.debug("Multi-day slot query: \(request.dateRange.start) to \(request.dateRange.end) -> querying \(startDate) to \(endDate)")
        }

        // Validate duration
        guard request.durationMinutes > 0 && request.durationMinutes <= 1440 else { // Max 24 hours
            throw ValidationError.invalidDuration(minutes: request.durationMinutes)
        }

        let dateRange = DateInterval(start: startDate, end: endDate)
        let duration = TimeInterval(request.durationMinutes * 60)
        let calendars = try calendarManager.getCalendarsFromRequest(
            calendarNames: request.calendarNames,
            calendarFilter: request.calendarFilter
        )
        let eveningHours = request.eveningHours ?? EveningHours()

        let slots = try await calendarManager.findAvailableSlots(
            in: dateRange,
            duration: duration,
            timePreferences: request.timePreferences,
            calendars: calendars,
            eveningHours: eveningHours,
            eventFilter: request.eventFilter?.toEventFilter()
        )

        let slotData = slots.map { $0.formattedOutput }

        return ["available_slots": slotData]
    }

    private func handleListCalendars(arguments: [String: Any]) async throws -> [String: Any] {
        let argumentsData = try JSONSerialization.data(withJSONObject: arguments)
        let request = try decoder.decode(ListCalendarsRequest.self, from: argumentsData)

        let calendars = try calendarManager.getCalendarsFromRequest(
            calendarNames: nil,
            calendarFilter: request.calendarFilter
        )

        let calendarData = calendars.map { calendar in
            [
                "name": calendar.title,
                "account": calendar.source.title,
                "account_type": sourceTypeDescription(calendar.source.sourceType),
                "type": calendarTypeDescription(calendar.type),
                "allows_modifications": calendar.allowsContentModifications,
                "is_subscribed": calendar.source.sourceType == .subscribed
            ] as [String: Any]
        }

        return [
            "calendars": calendarData,
            "count": calendars.count,
            "total_available": calendarManager.eventStore.calendars(for: .event).count
        ]
    }

    private func sourceTypeDescription(_ sourceType: EKSourceType) -> String {
        switch sourceType {
        case .local:
            return "local"
        case .exchange:
            return "exchange"
        case .calDAV:
            return "caldav"
        case .mobileMe:
            return "mobileme"
        case .subscribed:
            return "subscribed"
        case .birthdays:
            return "birthdays"
        @unknown default:
            return "unknown"
        }
    }

    private func calendarTypeDescription(_ calType: EKCalendarType) -> String {
        switch calType {
        case .local:
            return "local"
        case .calDAV:
            return "caldav"
        case .exchange:
            return "exchange"
        case .subscription:
            return "subscription"
        case .birthday:
            return "birthday"
        @unknown default:
            return "unknown"
        }
    }
    
    // MARK: - Event Management Handlers
    
    private func handleCreateEvent(arguments: [String: Any]) async throws -> [String: Any] {
        let argumentsData = try JSONSerialization.data(withJSONObject: arguments)
        let request = try decoder.decode(CreateEventRequest.self, from: argumentsData)
        
        let event = try await calendarManager.createEvent(request)
        
        return [
            "success": true,
            "event": [
                "id": event.eventIdentifier ?? "",
                "title": event.title ?? "",
                "start_datetime": DateUtils.iso8601Formatter.string(from: event.startDate),
                "end_datetime": DateUtils.iso8601Formatter.string(from: event.endDate),
                "calendar": event.calendar?.title ?? "",
                "location": event.location ?? "",
                "notes": event.notes ?? "",
                "is_all_day": event.isAllDay
            ],
            "message": "Event '\(event.title ?? "Untitled")' created successfully"
        ]
    }
    
    private func handleModifyEvent(arguments: [String: Any]) async throws -> [String: Any] {
        let argumentsData = try JSONSerialization.data(withJSONObject: arguments)
        let request = try decoder.decode(ModifyEventRequest.self, from: argumentsData)
        
        let event = try await calendarManager.modifyEvent(request)
        
        return [
            "success": true,
            "event": [
                "id": event.eventIdentifier ?? "",
                "title": event.title ?? "",
                "start_datetime": DateUtils.iso8601Formatter.string(from: event.startDate),
                "end_datetime": DateUtils.iso8601Formatter.string(from: event.endDate),
                "calendar": event.calendar?.title ?? "",
                "location": event.location ?? "",
                "notes": event.notes ?? "",
                "is_all_day": event.isAllDay
            ],
            "message": "Event '\(event.title ?? "Untitled")' modified successfully"
        ]
    }
    
    private func handleDeleteEvent(arguments: [String: Any]) async throws -> [String: Any] {
        let argumentsData = try JSONSerialization.data(withJSONObject: arguments)
        let request = try decoder.decode(DeleteEventRequest.self, from: argumentsData)
        
        let success = try await calendarManager.deleteEvent(request)
        
        return [
            "success": success,
            "message": success ? "Event deleted successfully" : "Failed to delete event"
        ]
    }
}
