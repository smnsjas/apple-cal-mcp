import ArgumentParser
import Foundation
import Logging

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

        logger.info("Starting Apple Calendar MCP Server")

        // Use RunLoop to keep async code running
        let runLoop = RunLoop.current
        let server = MCPServer(logger: logger)

        Task {
            do {
                try await server.start()
            } catch {
                logger.error("Server error: \(error)")
                Foundation.exit(1)
            }
        }

        // Keep the run loop running
        runLoop.run()
    }
}

AppleCalendarMCP.main()
