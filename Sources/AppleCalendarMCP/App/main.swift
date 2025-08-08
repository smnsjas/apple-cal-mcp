import ArgumentParser
import Foundation
import Logging
import EventKit

struct AppleCalendarMCP: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apple-cal-mcp",
        abstract: "Apple Calendar MCP Server for automated calendar checking and conflict detection"
    )

    @Flag(help: "Enable verbose logging")
    var verbose: Bool = false

    func run() throws {
        var logger = Logger(label: "apple-cal-mcp")
        logger.logLevel = verbose ? .debug : .info

        logger.info("Starting Apple Calendar MCP Server (permissions will be requested when needed)")
        
        // Use dispatchMain to keep the program running
        Task {
            let server = MCPServer(logger: logger)
            do {
                try await server.start()
            } catch {
                logger.error("Server error: \(error)")
                Foundation.exit(1)
            }
        }
        
        dispatchMain()
    }
}

AppleCalendarMCP.main()
