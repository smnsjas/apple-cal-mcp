import Foundation
import EventKit
import Logging
import ArgumentParser

final class MCPServer {
    private let logger: Logger
    private let calendarManager: CalendarManager
    private let jsonRPCHandler: JSONRPCHandler
    
    init(logger: Logger) {
        self.logger = logger
        self.calendarManager = CalendarManager(logger: logger)
        self.jsonRPCHandler = JSONRPCHandler(calendarManager: calendarManager, logger: logger)
    }
    
    func start() async throws {
        logger.info("Initializing calendar access...")
        
        // Request calendar permissions upfront
        try await calendarManager.requestCalendarAccess()
        
        logger.info("Calendar access granted. Starting MCP server...")
        logger.info("Reading JSON-RPC requests from stdin...")
        
        // Set up stdin/stdout communication for MCP protocol
        let stdin = FileHandle.standardInput
        let stdout = FileHandle.standardOutput
        
        // Read messages with Content-Length framing
        while true {
            do {
                guard let message = try readContentLengthMessage(from: stdin) else {
                    logger.info("No more input, shutting down...")
                    break
                }
                
                logger.debug("Received message: \(String(data: message, encoding: .utf8) ?? "<invalid UTF-8>")")
                
                let response = await jsonRPCHandler.handleRequest(message)
                try writeContentLengthMessage(response, to: stdout)
                
            } catch {
                logger.error("Error processing message: \(error)")
                // Send error response if possible
                let errorResponse = jsonRPCHandler.createErrorResponse(id: nil, error: .internalError("IO error: \(error)"))
                if let errorData = try? JSONEncoder().encode(errorResponse) {
                    try? writeContentLengthMessage(errorData, to: stdout)
                }
            }
        }
    }
    
    private func readContentLengthMessage(from handle: FileHandle) throws -> Data? {
        // Read headers until empty line
        var contentLength: Int?
        
        while true {
            guard let headerData = try readLine(from: handle),
                  let headerString = String(data: headerData, encoding: .utf8) else {
                return nil
            }
            
            let header = headerString.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if header.isEmpty {
                // Empty line indicates end of headers
                break
            }
            
            if header.hasPrefix("Content-Length:") {
                let lengthString = header.dropFirst("Content-Length:".count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                contentLength = Int(lengthString)
            }
        }
        
        guard let length = contentLength, length > 0 else {
            throw NSError(domain: "MCPError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid Content-Length header"])
        }
        
        // Read the message body
        let messageData = handle.readData(ofLength: length)
        guard messageData.count == length else {
            throw NSError(domain: "MCPError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Incomplete message body"])
        }
        
        return messageData
    }
    
    private func readLine(from handle: FileHandle) throws -> Data? {
        var lineData = Data()
        
        while true {
            let byte = handle.readData(ofLength: 1)
            if byte.isEmpty {
                return lineData.isEmpty ? nil : lineData
            }
            
            if byte[0] == 0x0A { // newline
                return lineData
            }
            
            lineData.append(byte)
        }
    }
    
    private func writeContentLengthMessage(_ data: Data, to handle: FileHandle) throws {
        let header = "Content-Length: \(data.count)\r\n\r\n"
        guard let headerData = header.data(using: .utf8) else {
            throw NSError(domain: "MCPError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode header"])
        }
        
        handle.write(headerData)
        handle.write(data)
        
        // Ensure immediate delivery
        if #available(macOS 10.15, *) {
            try handle.synchronize()
        }
    }
}