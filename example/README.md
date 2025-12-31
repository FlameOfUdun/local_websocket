# Local WebSocket Example

A comprehensive Flutter example demonstrating all features of the `local_websocket` package.

## Features

This example app includes three main sections accessible via bottom navigation:

### 1. 🖥️ Server Tab

- Start and stop a WebSocket server
- Configure server name, host, and port
- **Enable/disable authentication and validation delegates:**
  - Token Authentication - require clients to provide a token
  - Connection Logging - log client connect/disconnect events
  - Username Validation - require valid username (min 3 chars)
  - Message Validation - limit message length (500 chars)
- View connected clients in real-time
- Broadcast messages to all connected clients
- Monitor server logs and events

### 2. 📱 Client Tab

- Connect to a WebSocket server
- Configure username and connection URL
- **Enable token authentication** to connect to secured servers
- Send text messages to the server
- Send JSON-formatted messages
- View received messages in real-time
- Monitor connection status

### 3. 🔍 Scanner Tab

- Scan local network for WebSocket servers
- Configure host/subnet and port for scanning
- View discovered servers with their details
- Copy server URLs for easy connection

## Quick Start

### Prerequisites

- Flutter SDK installed
- A device or emulator to run the app

### Running the Example

- Navigate to the example directory:

```bash
cd example
```

- Get dependencies:

```bash
flutter pub get
```

- Run the app:

```bash
flutter run
```

## Usage Guide

### Testing Server-Client Communication

#### **Option 1: Single Device Testing**

1. **Start a Server**
   - Go to the "Server" tab
   - Keep the default settings (127.0.0.1:8080) or customize them
   - Tap "Start Server"
   - Note the server address displayed

2. **Connect a Client**
   - Go to the "Client" tab
   - Keep the default URL (ws://127.0.0.1:8080/ws) or update to match your server
   - Customize your username if desired
   - Tap "Connect"

3. **Send Messages**
   - Type a message in the text field
   - Tap the send button (📤) to send as plain text
   - Or tap the code button (</>) to send as JSON

4. **Broadcast from Server**
   - Go back to the "Server" tab
   - Type a message in the broadcast field
   - Press Enter to send to all connected clients

#### **Option 2: Multiple Devices/Instances**

1. Start the server on one device/instance
2. Note the server's IP address (use your local network IP instead of 127.0.0.1)
3. Run the app on another device/instance
4. In the Client tab, connect using the server's IP (e.g., ws://192.168.1.100:8080/ws)

#### **Option 3: Testing Scanner**

1. Start a server on the Server tab
2. Go to the Scanner tab
3. Configure the scan parameters:
   - For localhost: use "localhost" as host
   - For network scan: use your subnet (e.g., "192.168.1")
   - Set the port to match your server (default: 8080)
4. Tap "Start Scanning"
5. View discovered servers in the list

#### **Option 4: Testing Authentication & Validation**

1. **Enable Token Authentication**
   - Go to "Server" tab
   - Enable "Token Authentication" checkbox
   - Set a token (e.g., "secret123")
   - Start the server

2. **Connect Without Token (Will Fail)**
   - Go to "Client" tab
   - Try to connect without enabling token
   - Connection will be rejected with 401/403 error
   - Check server logs for authentication failure

3. **Connect With Token (Will Succeed)**
   - Enable "Use Token Authentication" checkbox
   - Enter the matching token
   - Tap "Connect"
   - Connection succeeds, check server logs

4. **Test Username Validation**
   - Enable "Username Validation" on server
   - Try connecting with username less than 3 characters
   - Connection will be rejected
   - Use valid username (3+ chars) to connect successfully

5. **Test Message Validation**
   - Enable "Message Validation" on server
   - Try sending empty message (rejected)
   - Try sending very long message >500 chars (rejected)
   - Send normal message (accepted)

## Example Scenarios

### Scenario 1: Chat Application

1. Start server in broadcast mode (default)
2. Connect multiple clients with different usernames
3. Send messages from any client
4. All other clients receive the message

### Scenario 2: Secured Chat with Authentication

1. Start server with token authentication enabled
2. Connect clients with matching token
3. Clients without valid token are rejected
4. Monitor authentication logs on server

### Scenario 3: Remote Control

1. Start server on one device
2. Connect client from another device
3. Send JSON commands from client
4. Server processes and broadcasts responses

### Scenario 3: Server Discovery

1. Start multiple servers on different ports
2. Use Scanner to find all available servers
3. Connect clients to discovered servers

## Configuration Options

### Server Configuration

- **Server Name**: Custom identifier for your server
- **Host**: IP address to bind (127.0.0.1 for local, 0.0.0.0 for all interfaces)
- **Port**: Port number (default: 8080)
- **Echo Mode**: Set in code (false = broadcast to others, true = echo to all including sender)

### Client Configuration

- **Username**: Display name for the client
- **WebSocket URL**: Full WebSocket URL (ws://host:port/ws)
- **Custom Details**: Additional metadata (configurable in code)

### Scanner Configuration

- **Host/Subnet**: IP or subnet to scan (e.g., "localhost" or "192.168.1")
- **Port**: Port to scan for servers
- **Scan Interval**: Configured in code (default: scans every few seconds)

## Tips

- **Testing Locally**: Use 127.0.0.1 for same-device testing
- **Network Testing**: Use your actual IP address (find it in your network settings)
- **Multiple Clients**: Open multiple app instances or use different devices
- **Message Format**: Supports String, Map, List, and other JSON-serializable types
- **Logs**: Check the Server tab logs for connection events and messages

## Troubleshooting

### **Server won't start**

- Check if the port is already in use
- Try a different port number
- Ensure you have network permissions

### **Client can't connect**

- Verify the server is running
- Check the WebSocket URL format (must start with ws://)
- Ensure host and port match the server
- Check firewall settings on network testing

### **Scanner finds no servers**

- Verify servers are actually running on the specified port
- Check network connectivity
- Try scanning "localhost" first for local testing
- Ensure servers have the correct details configured

## Code Structure

- `main.dart`: Entry point and main app structure
- `ServerPage`: WebSocket server implementation with UI
- `ClientPage`: WebSocket client implementation with UI
- `ScannerPage`: Network scanner implementation with UI

## Learn More

For detailed API documentation, see the [main package README](../README.md).

## License

This example is part of the local_websocket package and follows the same license.
