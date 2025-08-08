import Foundation

// MARK: - MCP Protocol Types

/// JSON-RPC ID can be string, number, or null per specification
typealias MCPRequestID = AnyCodable?

/// Represents an MCP JSON-RPC request with flexible ID handling
/// 
/// Supports the full JSON-RPC 2.0 specification including string, number, or null IDs.
/// The params field uses AnyCodable to handle arbitrary JSON structures from clients.
struct MCPRequest: Codable {
    let jsonrpc: String
    let id: MCPRequestID
    let method: String
    let params: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case jsonrpc, id, method, params
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jsonrpc = try container.decode(String.self, forKey: .jsonrpc)

        // ID can be string, number, or null
        if container.contains(.id) {
            id = try? container.decode(AnyCodable.self, forKey: .id)
        } else {
            id = nil
        }

        method = try container.decode(String.self, forKey: .method)

        if container.contains(.params) {
            params = try container.decode([String: AnyCodable].self, forKey: .params)
        } else {
            params = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)

        if let id = id {
            try container.encode(id, forKey: .id)
        } else {
            try container.encodeNil(forKey: .id)
        }

        try container.encode(method, forKey: .method)
        if let params = params {
            try container.encode(params, forKey: .params)
        }
    }

    func getParams() -> [String: Any]? {
        return params?.mapValues { $0.value }
    }
}

/// Represents an MCP JSON-RPC response with proper error handling
///
/// Follows JSON-RPC 2.0 specification where either result OR error is present, never both.
/// Uses AnyCodable encoding for flexible result structures.
struct MCPResponse: Encodable {
    let jsonrpc: String = "2.0"
    let id: MCPRequestID
    let result: [String: Any]?
    let error: MCPError?

    enum CodingKeys: String, CodingKey {
        case jsonrpc, id, result, error
    }

    init(id: MCPRequestID, result: [String: Any]? = nil, error: MCPError? = nil) {
        self.id = id
        self.result = result
        self.error = error
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)

        if let id = id {
            try container.encode(id, forKey: .id)
        } else {
            try container.encodeNil(forKey: .id)
        }

        if let result = result {
            try container.encode(AnyCodableDict(result), forKey: .result)
        }
        if let error = error {
            try container.encode(error, forKey: .error)
        }
    }
}

/// JSON-RPC 2.0 compliant error structure
///
/// Provides standard error codes (-32700 to -32603) and optional data field.
/// Implements LocalizedError for integration with Swift error handling.
struct MCPError: Error, Encodable {
    let code: Int
    let message: String
    let data: [String: Any]?

    enum CodingKeys: String, CodingKey {
        case code, message, data
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
        try container.encode(message, forKey: .message)
        if let data = data {
            try container.encode(AnyCodableDict(data), forKey: .data)
        }
    }

    // JSON-RPC error code constants
    static func parseError(_ message: String) -> MCPError {
        return MCPError(code: -32700, message: message, data: nil)
    }

    static func invalidRequest(_ message: String) -> MCPError {
        return MCPError(code: -32600, message: message, data: nil)
    }

    static func methodNotFound(_ message: String) -> MCPError {
        return MCPError(code: -32601, message: message, data: nil)
    }

    static func invalidParams(_ message: String) -> MCPError {
        return MCPError(code: -32602, message: message, data: nil)
    }

    static func internalError(_ message: String) -> MCPError {
        return MCPError(code: -32603, message: message, data: nil)
    }
}

// MARK: - Error Types

/// Typed validation errors with associated values for better error handling
enum ValidationError: Error, LocalizedError {
    case invalidDateFormat(String, expected: String = "YYYY-MM-DD")
    case dateOutOfRange(String, range: String = "1 year ago to 2 years from now")
    case tooManyDates(count: Int, maximum: Int)
    case invalidDateRange(reason: String)
    case invalidTimeFormat(String, expected: String = "HH:mm")
    case invalidTimeValues(String)
    case invalidDuration(minutes: Int, validRange: String = "1-1440")

    var errorDescription: String? {
        switch self {
        case .invalidDateFormat(let dateString, let expected):
            return "Invalid date format: \(dateString). Expected \(expected)"
        case .dateOutOfRange(let dateString, let range):
            return "Date \(dateString) is outside reasonable range (\(range))"
        case .tooManyDates(let count, let maximum):
            return "Too many dates requested. Maximum \(maximum) dates allowed, got \(count)"
        case .invalidDateRange(let reason):
            return "Invalid date range: \(reason)"
        case .invalidTimeFormat(let timeString, let expected):
            return "Invalid time format: \(timeString). Expected \(expected) format"
        case .invalidTimeValues(let details):
            return "Invalid time values: \(details)"
        case .invalidDuration(let minutes, let validRange):
            return "Invalid duration: \(minutes) minutes. Valid range: \(validRange)"
        }
    }
}

// MARK: - Calendar Types

/// Time availability preferences for calendar operations
///
/// - evening: Check availability during evening hours on weekdays, full day on weekends
/// - weekend: Check availability during full day on weekends/Fridays, evening hours on weekdays  
/// - all_day: Always check full day availability regardless of day of week
enum TimeType: String, Codable {
    case evening = "evening"
    case weekend = "weekend"
    case allDay = "all_day"
}

/// Status indicating whether calendar conflicts exist for a given time period
enum ConflictStatus: String, Codable {
    case available = "AVAILABLE"
    case conflict = "CONFLICT"
}

/// Defines the time range considered "evening hours" for calendar operations
///
/// Used by TimeType.evening and TimeType.weekend to determine when to check for conflicts.
/// Hours are stored in 24-hour format (0-23) with validation on initialization.
struct EveningHours: Codable {
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int

    init(start: String = "17:00", end: String = "23:00") throws {
        guard let (startHour, startMinute) = Self.parseTime(start) else {
            throw ValidationError.invalidTimeFormat(start)
        }
        guard let (endHour, endMinute) = Self.parseTime(end) else {
            throw ValidationError.invalidTimeFormat(end)
        }

        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
    }

    // Convenience initializer with defaults
    init() {
        self.startHour = 17
        self.startMinute = 0
        self.endHour = 23
        self.endMinute = 0
    }

    init(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) throws {
        guard Self.isValidTime(hour: startHour, minute: startMinute),
              Self.isValidTime(hour: endHour, minute: endMinute) else {
            throw ValidationError.invalidTimeValues("Hours must be 0-23, minutes 0-59")
        }

        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
    }

    private static func parseTime(_ timeString: String) -> (Int, Int)? {
        let components = timeString.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]),
              isValidTime(hour: hour, minute: minute) else {
            return nil
        }
        return (hour, minute)
    }

    private static func isValidTime(hour: Int, minute: Int) -> Bool {
        return (0...23).contains(hour) && (0...59).contains(minute)
    }
}

/// Detailed information about a calendar event with conflict analysis
///
/// Contains core event data plus optional conflict metadata when event represents
/// a scheduling conflict. Used in conflict analysis results.
struct EventDetail: Codable {
    let title: String
    let startTime: Date
    let endTime: Date
    let isAllDay: Bool
    let conflictType: String?
    let severity: String?
    let reason: String?
    let suggestion: String?

    init(
        title: String,
        startTime: Date,
        endTime: Date,
        isAllDay: Bool,
        conflictType: String? = nil,
        severity: String? = nil,
        reason: String? = nil,
        suggestion: String? = nil
    ) {
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.isAllDay = isAllDay
        self.conflictType = conflictType
        self.severity = severity
        self.reason = reason
        self.suggestion = suggestion
    }

    var timeString: String {
        if isAllDay {
            return "All day - \(DateUtils.humanDateFormatter.string(from: startTime))"
        } else {
            return "\(DateUtils.timeOnlyFormatter.string(from: startTime))-\(DateUtils.timeOnlyFormatter.string(from: endTime))"
        }
    }
}

/// Result of conflict analysis for a specific date
///
/// Contains the overall status plus detailed information about any conflicting events.
/// Includes summary statistics when conflicts are present.
struct ConflictResult: Codable {
    let status: ConflictStatus
    let events: [EventDetail]
    let summary: String?
    let totalConflicts: Int?
    let conflictsByType: [String: Int]?
}

/// Represents a contiguous block of available time in a calendar
///
/// Used by find_available_slots to return time periods when no conflicts exist.
/// Duration is provided in both TimeInterval and convenient minutes format.
struct AvailableSlot: Codable {
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval

    var durationMinutes: Int {
        return Int(duration / 60)
    }
}

// MARK: - Tool Request/Response Types

/// Request structure for check_calendar_conflicts tool
///
/// - Parameters:
///   - dates: Array of date strings in YYYY-MM-DD format
///   - timeType: Type of time availability to check (evening/weekend/all_day)
///   - calendarNames: Optional filter for specific calendar names
///   - calendarFilter: Advanced filtering options for calendars
///   - eveningHours: Custom evening hour range (defaults to 17:00-23:00)
struct CheckConflictsRequest: Codable {
    let dates: [String]
    let timeType: TimeType
    let calendarNames: [String]?
    let calendarFilter: CalendarFilterRequest?
    let eveningHours: EveningHours?

    enum CodingKeys: String, CodingKey {
        case dates
        case timeType = "time_type"
        case calendarNames = "calendar_names"
        case calendarFilter = "calendar_filter"
        case eveningHours = "evening_hours"
    }
}

/// Request structure for get_calendar_events tool
///
/// - Parameters:
///   - startDate: Start date in YYYY-MM-DD format  
///   - endDate: End date in YYYY-MM-DD format
///   - calendarNames: Optional filter for specific calendar names
///   - calendarFilter: Advanced filtering options for calendars
struct GetEventsRequest: Codable {
    let startDate: String
    let endDate: String
    let calendarNames: [String]?
    let calendarFilter: CalendarFilterRequest?

    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
        case calendarNames = "calendar_names"
        case calendarFilter = "calendar_filter"
    }
}

/// Request structure for find_available_slots tool
///
/// - Parameters:
///   - dateRange: Start and end dates for the search period
///   - durationMinutes: Minimum slot duration in minutes (1-1440)
///   - timePreferences: When to look for slots (evening/weekend/all_day)
///   - calendarNames: Optional filter for specific calendar names
///   - calendarFilter: Advanced filtering options for calendars
///   - eveningHours: Custom evening hour range (defaults to 17:00-23:00)
struct FindSlotsRequest: Codable {
    let dateRange: DateRange
    let durationMinutes: Int
    let timePreferences: TimeType
    let calendarNames: [String]?
    let calendarFilter: CalendarFilterRequest?
    let eveningHours: EveningHours?

    enum CodingKeys: String, CodingKey {
        case dateRange = "date_range"
        case durationMinutes = "duration_minutes"
        case timePreferences = "time_preferences"
        case calendarNames = "calendar_names"
        case calendarFilter = "calendar_filter"
        case eveningHours = "evening_hours"
    }
}

/// Request structure for list_calendars tool
///
/// - Parameters:
///   - calendarFilter: Filtering options to select specific calendars
struct ListCalendarsRequest: Codable {
    let calendarFilter: CalendarFilterRequest?

    enum CodingKeys: String, CodingKey {
        case calendarFilter = "calendar_filter"
    }
}

/// Date range specification using YYYY-MM-DD format strings
struct DateRange: Codable {
    let start: String
    let end: String
}

// MARK: - Encoding Helpers

struct AnyCodableDict: Encodable {
    let dict: [String: Any]

    init(_ dict: [String: Any]) {
        self.dict = dict
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let encodableDict = dict.mapValues { AnyCodable($0) }
        try container.encode(encodableDict)
    }
}

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
