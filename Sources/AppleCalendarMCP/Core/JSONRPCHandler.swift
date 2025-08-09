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
        return MCPResponse(id: id ?? nil, error: error)
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
                                ]
                            ]
                        ]
                    ]
                ]
            ],
            [
                "name": "check_calendar_conflicts",
                "description": "Check multiple dates for calendar conflicts based on time preferences",
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
                "description": "Get all events in a specified date range",
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
            eveningHours: eveningHours
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
        let endDate = try DateUtils.parseDate(request.endDate)

        try DateUtils.validateDateRange(start: startDate, end: endDate)

        let calendars = try calendarManager.getCalendarsFromRequest(
            calendarNames: request.calendarNames,
            calendarFilter: request.calendarFilter
        )
        let events = await calendarManager.getEvents(from: startDate, to: endDate, calendars: calendars)

        let eventData = events.map { $0.formattedOutput }

        return ["events": eventData]
    }

    private func handleFindSlots(arguments: [String: Any]) async throws -> [String: Any] {
        let argumentsData = try JSONSerialization.data(withJSONObject: arguments)
        let request = try decoder.decode(FindSlotsRequest.self, from: argumentsData)

        let startDate = try DateUtils.parseDate(request.dateRange.start)
        let endDate = try DateUtils.parseDate(request.dateRange.end)

        try DateUtils.validateDateRange(start: startDate, end: endDate)

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
            eveningHours: eveningHours
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
}
