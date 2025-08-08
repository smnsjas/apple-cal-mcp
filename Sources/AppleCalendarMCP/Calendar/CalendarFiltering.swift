import Foundation
import EventKit

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
    
    enum CodingKeys: String, CodingKey {
        case includeNames = "include_names"
        case excludeNames = "exclude_names" 
        case includeAccounts = "include_accounts"
        case excludeAccounts = "exclude_accounts"
        case excludeReadOnly = "exclude_read_only"
        case excludeSubscribed = "exclude_subscribed"
        case excludeHolidays = "exclude_holidays"
        case excludeSports = "exclude_sports"
    }
    
    func toCalendarFilter() -> CalendarFilter {
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