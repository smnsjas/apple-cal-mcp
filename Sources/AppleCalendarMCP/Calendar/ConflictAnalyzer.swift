import Foundation
import EventKit

struct ConflictReason {
    let type: ConflictType
    let description: String
    let severity: ConflictSeverity
    let suggestion: String?
}

enum ConflictType: String, CaseIterable {
    case meeting = "meeting"
    case appointment = "appointment"
    case personal = "personal"
    case travel = "travel"
    case medical = "medical"
    case family = "family"
    case social = "social"
    case work = "work"
    case allDay = "all_day"
    case recurring = "recurring"
    case unknown = "unknown"
}

enum ConflictSeverity: String {
    case low = "low"           // Could potentially be moved
    case medium = "medium"     // Important but might have flexibility
    case high = "high"         // Hard to reschedule
    case critical = "critical" // Should not be moved
}

final class ConflictAnalyzer {
    
    func analyzeConflicts(_ events: [EKEvent], for date: Date, timeType: TimeType) -> [ConflictReason] {
        return events.map { event in
            let conflictType = classifyEvent(event)
            let severity = determineSeverity(event, type: conflictType)
            let description = generateDescription(event, type: conflictType, severity: severity)
            let suggestion = generateSuggestion(event, type: conflictType, severity: severity, timeType: timeType)
            
            return ConflictReason(
                type: conflictType,
                description: description,
                severity: severity,
                suggestion: suggestion
            )
        }
    }
    
    private func classifyEvent(_ event: EKEvent) -> ConflictType {
        let title = event.title?.lowercased() ?? ""
        let calendar = event.calendar?.title.lowercased() ?? ""
        
        // Medical appointments
        if title.contains("doctor") || title.contains("dentist") || title.contains("appointment") ||
           title.contains("medical") || title.contains("therapy") || title.contains("checkup") ||
           title.contains("surgery") || title.contains("clinic") || title.contains("hospital") {
            return .medical
        }
        
        // Travel
        if title.contains("travel") || title.contains("flight") || title.contains("trip") ||
           title.contains("vacation") || title.contains("out of town") || title.contains("away") ||
           title.contains("conference") && (title.contains("travel") || title.contains("flight")) {
            return .travel
        }
        
        // Family events
        if title.contains("family") || title.contains("wife") || title.contains("husband") ||
           title.contains("kids") || title.contains("children") || title.contains("school") ||
           title.contains("parent") || title.contains("birthday") || title.contains("anniversary") ||
           calendar.contains("family") {
            return .family
        }
        
        // Work meetings
        if title.contains("meeting") || title.contains("call") || title.contains("standup") ||
           title.contains("review") || title.contains("interview") || title.contains("presentation") ||
           title.contains("team") || title.contains("client") || calendar.contains("work") ||
           calendar.contains("exchange") {
            return .work
        }
        
        // Social events
        if title.contains("dinner") || title.contains("lunch") || title.contains("party") ||
           title.contains("event") || title.contains("social") || title.contains("friends") ||
           title.contains("date") || title.contains("celebration") {
            return .social
        }
        
        // Personal appointments
        if title.contains("appointment") || title.contains("service") || title.contains("maintenance") ||
           title.contains("repair") || title.contains("personal") {
            return .appointment
        }
        
        // All-day events
        if event.isAllDay {
            return .allDay
        }
        
        // Recurring events
        if event.hasRecurrenceRules {
            return .recurring
        }
        
        // Generic meeting if nothing else matches but has meeting-like characteristics
        if title.contains("meet") || title.contains("sync") || title.contains("check-in") {
            return .meeting
        }
        
        return .unknown
    }
    
    private func determineSeverity(_ event: EKEvent, type: ConflictType) -> ConflictSeverity {
        let title = event.title?.lowercased() ?? ""
        
        // Critical events that should never be moved
        if type == .medical && (title.contains("surgery") || title.contains("procedure")) {
            return .critical
        }
        
        if type == .travel || title.contains("flight") || title.contains("out of town") {
            return .critical
        }
        
        if title.contains("interview") || title.contains("important") || title.contains("urgent") {
            return .critical
        }
        
        // High priority events
        if type == .medical || type == .family {
            return .high
        }
        
        if title.contains("client") || title.contains("presentation") || title.contains("demo") {
            return .high
        }
        
        if event.isAllDay {
            return .high
        }
        
        // Medium priority
        if type == .work || type == .appointment {
            return .medium
        }
        
        if event.hasRecurrenceRules {
            return .medium
        }
        
        // Low priority - more flexible events
        if type == .social {
            return .low
        }
        
        return .medium
    }
    
    private func generateDescription(_ event: EKEvent, type: ConflictType, severity: ConflictSeverity) -> String {
        let title = event.title ?? "Untitled event"
        let timeString = event.isAllDay ? "All day" : "\(DateUtils.timeOnlyFormatter.string(from: event.startDate))-\(DateUtils.timeOnlyFormatter.string(from: event.endDate))"
        
        switch type {
        case .medical:
            return "Medical appointment: \(title) (\(timeString))"
        case .travel:
            return "Travel/Trip: \(title) (\(timeString))"
        case .family:
            return "Family commitment: \(title) (\(timeString))"
        case .work:
            return "Work meeting: \(title) (\(timeString))"
        case .social:
            return "Social event: \(title) (\(timeString))"
        case .appointment:
            return "Appointment: \(title) (\(timeString))"
        case .allDay:
            return "All-day event: \(title)"
        case .recurring:
            return "Recurring event: \(title) (\(timeString))"
        default:
            return "\(title) (\(timeString))"
        }
    }
    
    private func generateSuggestion(_ event: EKEvent, type: ConflictType, severity: ConflictSeverity, timeType: TimeType) -> String? {
        switch severity {
        case .critical:
            return "This is a critical event that cannot be moved. Consider scheduling around it."
        case .high:
            return "High priority event. Moving would be difficult but possible with advance notice."
        case .medium:
            switch type {
            case .work:
                return "Work meeting could potentially be rescheduled with proper notice."
            case .recurring:
                return "Recurring event - consider if this instance can be skipped or moved."
            default:
                return "Moderate priority - some flexibility for rescheduling."
            }
        case .low:
            return "Lower priority event that could be moved if needed."
        }
    }
    
    func generateConflictSummary(_ reasons: [ConflictReason]) -> String {
        if reasons.isEmpty {
            return "No conflicts found"
        }
        
        let criticalCount = reasons.filter { $0.severity == .critical }.count
        let highCount = reasons.filter { $0.severity == .high }.count
        let mediumCount = reasons.filter { $0.severity == .medium }.count
        let lowCount = reasons.filter { $0.severity == .low }.count
        
        var summary = "\(reasons.count) conflict\(reasons.count == 1 ? "" : "s")"
        
        if criticalCount > 0 {
            summary += " (\(criticalCount) critical"
            if highCount + mediumCount + lowCount > 0 {
                summary += ", \(highCount + mediumCount + lowCount) other\(highCount + mediumCount + lowCount == 1 ? "" : "s")"
            }
            summary += ")"
        } else if highCount > 0 {
            summary += " (\(highCount) high priority"
            if mediumCount + lowCount > 0 {
                summary += ", \(mediumCount + lowCount) moderate"
            }
            summary += ")"
        } else {
            summary += " (all moderate/low priority)"
        }
        
        return summary
    }
}