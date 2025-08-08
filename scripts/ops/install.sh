#!/bin/bash

# Apple Calendar MCP Server Installation Script

set -e

echo "🍎 Installing Apple Calendar MCP Server..."

# Build the project in release mode
echo "Building project..."
swift build -c release

# Create installation directory
INSTALL_DIR="/usr/local/bin"
EXECUTABLE_NAME="apple-cal-mcp"
SOURCE_PATH=".build/release/$EXECUTABLE_NAME"
INSTALL_PATH="$INSTALL_DIR/$EXECUTABLE_NAME"

# Check if we need sudo for installation
if [[ ! -w "$INSTALL_DIR" ]]; then
    echo "Installing to $INSTALL_DIR (requires admin privileges)..."
    sudo cp "$SOURCE_PATH" "$INSTALL_PATH"
    sudo chmod +x "$INSTALL_PATH"
else
    echo "Installing to $INSTALL_DIR..."
    cp "$SOURCE_PATH" "$INSTALL_PATH"
    chmod +x "$INSTALL_PATH"
fi

echo "✅ Installation complete!"
echo ""
echo "Next steps:"
echo "1. Add this server to your MCP client configuration:"
echo '   {
     "mcpServers": {
       "apple-calendar": {
         "command": "/usr/local/bin/apple-cal-mcp",
         "args": ["--verbose"]
       }
     }
   }'
echo ""
echo "2. When first run, macOS will prompt for Calendar access permission."
echo "3. Grant permission to enable calendar integration."
echo ""
echo "Test installation with: $INSTALL_PATH --help"