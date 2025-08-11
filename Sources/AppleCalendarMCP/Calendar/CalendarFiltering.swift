import EventKit
import Foundation

// Event type filtering
struct EventFilter {
    let excludeAllDay: Bool
    let excludeBusy: Bool
    let excludeTentative: Bool
    let excludePrivate: Bool
    let titleContains: [String]?
    let titleExcludes: [String]?
    let minimumDuration: TimeInterval? // in seconds
    let maximumDuration: TimeInterval? // in seconds
    let workMeetingsOnly: Bool // Smart work meeting detection
    let businessHoursOnly: Bool // Only events during business hours
    
    init(
        excludeAllDay: Bool = false,
        excludeBusy: Bool = false,
        excludeTentative: Bool = false,
        excludePrivate: Bool = false,
        titleContains: [String]? = nil,
        titleExcludes: [String]? = nil,
        minimumDuration: TimeInterval? = nil,
        maximumDuration: TimeInterval? = nil,
        workMeetingsOnly: Bool = false,
        businessHoursOnly: Bool = false
    ) {
        self.excludeAllDay = excludeAllDay
        self.excludeBusy = excludeBusy
        self.excludeTentative = excludeTentative
        self.excludePrivate = excludePrivate
        self.titleContains = titleContains
        self.titleExcludes = titleExcludes
        self.minimumDuration = minimumDuration
        self.maximumDuration = maximumDuration
        self.workMeetingsOnly = workMeetingsOnly
        self.businessHoursOnly = businessHoursOnly
    }
}

struct EventFilterRequest: Codable {
    let excludeAllDay: Bool?
    let excludeBusy: Bool?
    let excludeTentative: Bool?
    let excludePrivate: Bool?
    let titleContains: [String]?
    let titleExcludes: [String]?
    let minimumDuration: Double? // in minutes
    let maximumDuration: Double? // in minutes
    let workMeetingsOnly: Bool?
    let businessHoursOnly: Bool?
    
    enum CodingKeys: String, CodingKey {
        case excludeAllDay = "exclude_all_day"
        case excludeBusy = "exclude_busy"
        case excludeTentative = "exclude_tentative"
        case excludePrivate = "exclude_private"
        case titleContains = "title_contains"
        case titleExcludes = "title_excludes"
        case minimumDuration = "minimum_duration_minutes"
        case maximumDuration = "maximum_duration_minutes"
        case workMeetingsOnly = "work_meetings_only"
        case businessHoursOnly = "business_hours_only"
    }
    
    func toEventFilter() -> EventFilter {
        return EventFilter(
            excludeAllDay: excludeAllDay ?? false,
            excludeBusy: excludeBusy ?? false,
            excludeTentative: excludeTentative ?? false,
            excludePrivate: excludePrivate ?? false,
            titleContains: titleContains,
            titleExcludes: titleExcludes,
            minimumDuration: minimumDuration.map { $0 * 60 }, // Convert minutes to seconds
            maximumDuration: maximumDuration.map { $0 * 60 },  // Convert minutes to seconds
            workMeetingsOnly: workMeetingsOnly ?? false,
            businessHoursOnly: businessHoursOnly ?? false
        )
    }
}

struct CalendarFilter {
    let includeNames: [String]?
    let excludeNames: [String]?
    let includeAccounts: [String]?
    let excludeAccounts: [String]?
    let excludeReadOnly: Bool
    let excludeSubscribed: Bool
    let excludeHolidays: Bool
    let excludeSports: Bool

    init(
        includeNames: [String]? = nil,
        excludeNames: [String]? = nil,
        includeAccounts: [String]? = nil,
        excludeAccounts: [String]? = nil,
        excludeReadOnly: Bool = false,
        excludeSubscribed: Bool = false,
        excludeHolidays: Bool = false,
        excludeSports: Bool = false
    ) {
        self.includeNames = includeNames
        self.excludeNames = excludeNames
        self.includeAccounts = includeAccounts
        self.excludeAccounts = excludeAccounts
        self.excludeReadOnly = excludeReadOnly
        self.excludeSubscribed = excludeSubscribed
        self.excludeHolidays = excludeHolidays
        self.excludeSports = excludeSports
    }
}

extension CalendarManager {
    func getFilteredCalendars(filter: CalendarFilter) throws -> [EKCalendar] {
        let allCalendars = eventStore.calendars(for: .event)

        return allCalendars.filter { calendar in
            // Include by name filter
            if let includeNames = filter.includeNames {
                if !includeNames.contains(calendar.title) {
                    return false
                }
            }

            // Exclude by name filter
            if let excludeNames = filter.excludeNames {
                if excludeNames.contains(calendar.title) {
                    return false
                }
            }

            // Include by account filter
            if let includeAccounts = filter.includeAccounts {
                if !includeAccounts.contains(calendar.source.title) {
                    return false
                }
            }

            // Exclude by account filter
            if let excludeAccounts = filter.excludeAccounts {
                if excludeAccounts.contains(calendar.source.title) {
                    return false
                }
            }

            // Exclude read-only calendars
            if filter.excludeReadOnly && !calendar.allowsContentModifications {
                return false
            }

            // Exclude subscribed calendars
            if filter.excludeSubscribed && calendar.source.sourceType == .subscribed {
                return false
            }

            // Exclude holiday calendars
            if filter.excludeHolidays {
                let title = calendar.title.lowercased()
                if title.contains("holiday") || title.contains("birthdays") {
                    return false
                }
            }

            // Exclude sports calendars
            if filter.excludeSports {
                let title = calendar.title.lowercased()
                if title.contains("hurricanes") ||
                   title.contains("orange") ||
                   title.contains("ncaa") ||
                   title.contains("football") ||
                   title.contains("sports") {
                    return false
                }
            }

            return true
        }
    }

    func getWorkCalendars() throws -> [EKCalendar] {
        return try getFilteredCalendars(filter: CalendarFilter(
            includeNames: ["Calendar", "Work"],
            excludeSubscribed: true,
            excludeHolidays: true,
            excludeSports: true
        ))
    }

    func getPersonalCalendars() throws -> [EKCalendar] {
        return try getFilteredCalendars(filter: CalendarFilter(
            excludeNames: ["Birthdays", "US Holidays"],
            includeAccounts: ["iCloud", "jpsimons@gmail.com"],
            excludeSubscribed: true,
            excludeSports: true
        ))
    }

    func getMainCalendars() throws -> [EKCalendar] {
        // Most relevant calendars for conflict checking
        return try getFilteredCalendars(filter: CalendarFilter(
            includeNames: ["Calendar", "Work", "Home", "Personal", "Family"],
            excludeSubscribed: true,
            excludeHolidays: true,
            excludeSports: true
        ))
    }
    
    func filterEvents(_ events: [EKEvent], using filter: EventFilter) -> [EKEvent] {
        return events.filter { event in
            // Exclude all-day events
            if filter.excludeAllDay && event.isAllDay {
                return false
            }
            
            // Exclude busy events (availability = .busy)
            if filter.excludeBusy && event.availability == .busy {
                return false
            }
            
            // Exclude tentative events (availability = .tentative)
            if filter.excludeTentative && event.availability == .tentative {
                return false
            }
            
            // Exclude private events (note: EKEvent doesn't have visibility property in EventKit)
            // This filter is included for API completeness but doesn't function on macOS
            // if filter.excludePrivate && event.visibility == .private {
            //     return false
            // }
            
            // Business hours filter (8 AM - 6 PM)
            if filter.businessHoursOnly {
                let calendar = Calendar.current
                let startHour = calendar.component(.hour, from: event.startDate)
                if startHour < 8 || startHour >= 18 {
                    return false
                }
            }
            
            // Smart work meeting detection
            if filter.workMeetingsOnly {
                if !isLikelyWorkMeeting(event) {
                    return false
                }
            }
            
            // Title contains filter (only if not using smart detection)
            if let titleContains = filter.titleContains, !filter.workMeetingsOnly {
                let title = event.title?.lowercased() ?? ""
                let hasMatchingKeyword = titleContains.contains { keyword in
                    title.contains(keyword.lowercased())
                }
                if !hasMatchingKeyword {
                    return false
                }
            }
            
            // Title excludes filter
            if let titleExcludes = filter.titleExcludes {
                let title = event.title?.lowercased() ?? ""
                let hasExcludedKeyword = titleExcludes.contains { keyword in
                    title.contains(keyword.lowercased())
                }
                if hasExcludedKeyword {
                    return false
                }
            }
            
            // Duration filters
            let duration = event.endDate.timeIntervalSince(event.startDate)
            
            if let minDuration = filter.minimumDuration, duration < minDuration {
                return false
            }
            
            if let maxDuration = filter.maximumDuration, duration > maxDuration {
                return false
            }
            
            return true
        }
    }
    
    /// Smart work meeting detection using multiple heuristics
    private func isLikelyWorkMeeting(_ event: EKEvent) -> Bool {
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: event.startDate)
        let duration = event.endDate.timeIntervalSince(event.startDate)
        let title = event.title?.lowercased() ?? ""
        
        var score = 0
        
        // Time-based scoring
        if startHour >= 8 && startHour <= 17 { // 8 AM - 5 PM
            score += 3 // Strong indicator
        } else if startHour >= 7 && startHour <= 19 { // 7 AM - 7 PM  
            score += 1 // Moderate indicator
        }
        
        // Duration-based scoring
        if duration >= 1800 { // 30+ minutes
            score += 2
        } else if duration >= 900 { // 15+ minutes
            score += 1
        }
        
        // Calendar-based scoring
        let calendarTitle = event.calendar?.title.lowercased() ?? ""
        if calendarTitle.contains("work") || calendarTitle.contains("office") || calendarTitle == "calendar" {
            score += 2
        }
        
        // Title-based scoring (positive indicators)
        let workKeywords = ["meeting", "call", "sync", "standup", "review", "demo", "planning", "team", "project", "discussion", "interview", "presentation", "workshop", "training"]
        let hasWorkKeyword = workKeywords.contains { keyword in
            title.contains(keyword)
        }
        if hasWorkKeyword {
            score += 2
        }
        
        // Title patterns that suggest work meetings
        if title.contains(" - ") || // "Drew Stinnett - S - 2h" pattern
           title.contains("team") ||
           title.contains("devops") ||
           title.contains("windows") {
            score += 2
        }
        
        // Exclude obvious personal events
        let personalKeywords = ["birthday", "anniversary", "vacation", "holiday", "personal", "doctor", "dentist", "lunch", "dinner", "breakfast"]
        let hasPersonalKeyword = personalKeywords.contains { keyword in
            title.contains(keyword)
        }
        if hasPersonalKeyword {
            score -= 3
        }
        
        // Weekday bonus
        let weekday = calendar.component(.weekday, from: event.startDate)
        if weekday >= 2 && weekday <= 6 { // Monday-Friday
            score += 1
        }
        
        // Score threshold: 4+ points = likely work meeting
        return score >= 4
    }
}

// Enhanced request models with filtering options
struct CalendarFilterRequest: Codable {
    let includeNames: [String]?
    let excludeNames: [String]?
    let includeAccounts: [String]?
    let excludeAccounts: [String]?
    let excludeReadOnly: Bool?
    let excludeSubscribed: Bool?
    let excludeHolidays: Bool?
    let excludeSports: Bool?
    let preset: String? // Quick preset filters

    enum CodingKeys: String, CodingKey {
        case includeNames = "include_names"
        case excludeNames = "exclude_names"
        case includeAccounts = "include_accounts"
        case excludeAccounts = "exclude_accounts"
        case excludeReadOnly = "exclude_read_only"
        case excludeSubscribed = "exclude_subscribed"
        case excludeHolidays = "exclude_holidays"
        case excludeSports = "exclude_sports"
        case preset = "preset"
    }

    func toCalendarFilter() -> CalendarFilter {
        // Handle preset filters first
        if let preset = preset {
            switch preset.lowercased() {
            case "work":
                return CalendarFilter(
                    includeNames: ["Calendar", "Work"],
                    excludeSubscribed: true,
                    excludeHolidays: true,
                    excludeSports: true
                )
            case "personal":
                return CalendarFilter(
                    excludeNames: ["Birthdays", "US Holidays"],
                    includeAccounts: ["iCloud", "jpsimons@gmail.com"],
                    excludeSubscribed: true,
                    excludeSports: true
                )
            case "main":
                return CalendarFilter(
                    includeNames: ["Calendar", "Work", "Home", "Personal", "Family"],
                    excludeSubscribed: true,
                    excludeHolidays: true,
                    excludeSports: true
                )
            case "all":
                return CalendarFilter() // No filters applied
            case "debug":
                // Show everything for debugging filtering issues
                return CalendarFilter()
            case "clean":
                return CalendarFilter(
                    excludeReadOnly: true,
                    excludeSubscribed: true,
                    excludeHolidays: true,
                    excludeSports: true
                )
            default:
                break // Fall through to manual configuration
            }
        }
        
        return CalendarFilter(
            includeNames: includeNames,
            excludeNames: excludeNames,
            includeAccounts: includeAccounts,
            excludeAccounts: excludeAccounts,
            excludeReadOnly: excludeReadOnly ?? false,
            excludeSubscribed: excludeSubscribed ?? false,
            excludeHolidays: excludeHolidays ?? false,
            excludeSports: excludeSports ?? false
        )
    }
}
