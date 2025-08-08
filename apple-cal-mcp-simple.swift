#!/usr/bin/env swift

import Foundation

// Simple MCP server that just runs
print("Content-Length: 89\r\n\r\n{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{}}}")
fflush(stdout)

// Keep running to accept more requests
while true {
    if let line = readLine() {
        if line.isEmpty { break }
    }
}