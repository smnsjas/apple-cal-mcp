#!/usr/bin/env swift

import Foundation
import EventKit

// Simple test to trigger calendar permissions
print("🧪 Testing Calendar Permissions")
print("===============================")

let eventStore = EKEventStore()

print("Current authorization status:", EKEventStore.authorizationStatus(for: .event))

// This should trigger the permission dialog
Task {
    do {
        print("Requesting calendar access...")
        let granted = try await eventStore.requestAccess(to: .event)
        
        if granted {
            print("✅ Calendar access granted!")
            
            // Try to get calendars
            let calendars = eventStore.calendars(for: .event)
            print("📅 Found \(calendars.count) calendars:")
            for calendar in calendars {
                print("  - \(calendar.title) (\(calendar.source.title))")
            }
        } else {
            print("❌ Calendar access denied")
        }
        
    } catch {
        print("❌ Error requesting calendar access: \(error)")
    }
    
    exit(0)
}

// Keep the program alive
RunLoop.main.run()