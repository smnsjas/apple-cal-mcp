#!/usr/bin/env swift

import ArgumentParser
import Foundation
import Logging

struct TestServer: ParsableCommand {
    @Flag(help: "Enable verbose logging")
    var verbose: Bool = false

    func run() throws {
        print("Hello from minimal test server")
        if verbose {
            print("Verbose mode enabled")
        }
    }
}

TestServer.main()