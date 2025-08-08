import XCTest
@testable import AppleCalendarMCP
import Logging

final class JSONRPCHandlerTests: XCTestCase {
    var handler: JSONRPCHandler!
    var calendarManager: CalendarManager!
    
    override func setUp() {
        super.setUp()
        let logger = Logger(label: "test")
        calendarManager = CalendarManager(logger: logger)
        handler = JSONRPCHandler(calendarManager: calendarManager, logger: logger)
    }
    
    // MARK: - Error Path Tests
    
    func testInvalidJSONRequest() async {
        let invalidJSON = Data("invalid json".utf8)
        let response = await handler.handleRequest(invalidJSON)
        
        let responseDict = try! JSONSerialization.jsonObject(with: response) as! [String: Any]
        
        XCTAssertEqual(responseDict["jsonrpc"] as? String, "2.0")
        // Parse error should have null id, which JSON converts to NSNull
        XCTAssertTrue(responseDict["id"] is NSNull)
        XCTAssertNotNil(responseDict["error"])
        
        let error = responseDict["error"] as! [String: Any]
        XCTAssertEqual(error["code"] as? Int, -32700) // Parse error
    }
    
    func testUnknownMethod() async {
        let request = createMCPRequest(id: "test-1", method: "unknown_method", params: nil)
        let response = await handler.handleRequest(request)
        
        let responseDict = try! JSONSerialization.jsonObject(with: response) as! [String: Any]
        
        XCTAssertEqual(responseDict["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(responseDict["id"] as? String, "test-1")
        XCTAssertNotNil(responseDict["error"])
        
        let error = responseDict["error"] as! [String: Any]
        XCTAssertEqual(error["code"] as? Int, -32601) // Method not found
    }
    
    func testUnknownTool() async {
        let params: [String: Any] = [
            "name": "unknown_tool",
            "arguments": [:]
        ]
        let request = createMCPRequest(id: "test-1", method: "tools/call", params: params)
        let response = await handler.handleRequest(request)
        
        let responseDict = try! JSONSerialization.jsonObject(with: response) as! [String: Any]
        
        XCTAssertEqual(responseDict["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(responseDict["id"] as? String, "test-1")
        XCTAssertNotNil(responseDict["error"])
        
        let error = responseDict["error"] as! [String: Any]
        XCTAssertEqual(error["code"] as? Int, -32602) // Invalid parameters / Unknown tool
    }
    
    // Note: Calendar-dependent tests require EventKit access and are better tested via integration tests
    // These tests focus on JSON-RPC protocol handling without calendar interactions
    
    // MARK: - Success Path Tests
    
    func testInitializeMethod() async {
        let request = createMCPRequest(id: "test-1", method: "initialize", params: nil)
        let response = await handler.handleRequest(request)
        
        let responseDict = try! JSONSerialization.jsonObject(with: response) as! [String: Any]
        
        XCTAssertEqual(responseDict["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(responseDict["id"] as? String, "test-1")
        XCTAssertNil(responseDict["error"])
        
        let result = responseDict["result"] as! [String: Any]
        XCTAssertEqual(result["protocolVersion"] as? String, "2024-11-05")
        XCTAssertNotNil(result["capabilities"])
        XCTAssertNotNil(result["serverInfo"])
    }
    
    func testToolsListMethod() async {
        let request = createMCPRequest(id: "test-1", method: "tools/list", params: nil)
        let response = await handler.handleRequest(request)
        
        let responseDict = try! JSONSerialization.jsonObject(with: response) as! [String: Any]
        
        XCTAssertEqual(responseDict["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(responseDict["id"] as? String, "test-1")
        XCTAssertNil(responseDict["error"])
        
        let result = responseDict["result"] as! [String: Any]
        let tools = result["tools"] as! [[String: Any]]
        XCTAssertGreaterThan(tools.count, 0)
        
        // Verify all expected tools are present
        let toolNames = tools.compactMap { $0["name"] as? String }
        XCTAssertTrue(toolNames.contains("list_calendars"))
        XCTAssertTrue(toolNames.contains("check_calendar_conflicts"))
        XCTAssertTrue(toolNames.contains("get_calendar_events"))
        XCTAssertTrue(toolNames.contains("find_available_slots"))
    }
    
    // MARK: - Helper Methods
    
    private func createMCPRequest(id: String, method: String, params: [String: Any]?) -> Data {
        var request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": method
        ]
        
        if let params = params {
            request["params"] = params
        }
        
        return try! JSONSerialization.data(withJSONObject: request)
    }
}