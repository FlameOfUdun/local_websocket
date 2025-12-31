# Running the Examples

This folder contains multiple examples demonstrating the `local_websocket` package:

## 1. Flutter GUI Example (Recommended)

The main Flutter application with a full graphical interface.

**Run with:**

```bash
cd example
flutter run
```

This provides:

- Server management UI
- Client connection UI
- Network scanner UI
- Real-time message display
- Interactive controls

See [README.md](README.md) for detailed usage instructions.

## 2. CLI Examples

Command-line examples for testing without a GUI.

### Server Example

Start a WebSocket server from the command line:

```bash
dart run example/lib/cli_server_example.dart
```

This will:

- Start a server on `127.0.0.1:8080`
- Display server address and endpoints
- Show connected clients
- Log all messages
- Run until you press Ctrl+C

### Client Example

Connect a client to a running server:

```bash
dart run example/lib/cli_client_example.dart
```

This will:

- Connect to `ws://127.0.0.1:8080/ws`
- Send test messages (text, JSON, list)
- Display received messages
- Run until you press Ctrl+C

**Note:** Make sure the server is running first!

### Scanner Example

Scan for available WebSocket servers:

```bash
dart run example/lib/cli_scanner_example.dart
```

This will:

- Scan `localhost:8080` for servers
- Display found servers and their details
- Continuously scan every few seconds
- Run until you press Ctrl+C

**Note:** Make sure at least one server is running to see results!

## Testing Multiple Clients

### Option 1: Multiple Terminal Windows

1. **Terminal 1** - Start server:

   ```bash
   dart run example/lib/cli_server_example.dart
   ```

2. **Terminal 2** - Connect first client:

   ```bash
   dart run example/lib/cli_client_example.dart
   ```

3. **Terminal 3** - Connect second client:

   ```bash
   dart run example/lib/cli_client_example.dart
   ```

4. **Terminal 4** - Run scanner:

   ```bash
   dart run example/lib/cli_scanner_example.dart
   ```

### Option 2: Mix CLI and GUI

1. Start server with CLI:

   ```bash
   dart run example/lib/cli_server_example.dart
   ```

2. Run Flutter app and connect clients:

   ```bash
   flutter run
   ```

   Then use the Client tab to connect multiple instances.

### Option 3: All GUI

1. Run the Flutter app:

   ```bash
   flutter run
   ```

2. Use the Server tab to start a server

3. Use the Client tab to connect

4. Use the Scanner tab to discover servers

## Tips

- **Local Testing**: Use `127.0.0.1` or `localhost` for same-machine testing
- **Network Testing**: Use your actual IP address (e.g., `192.168.1.100`)
  - Find your IP: `ipconfig` (Windows) or `ifconfig` (Mac/Linux)
- **Port Already in Use**: If port 8080 is busy, use a different port like 8081, 8082, etc.
- **Message Format**: The package supports String, Map, List, and any JSON-serializable type

## Common Workflows

### Workflow 1: Quick Test

```bash
# Terminal 1
dart run example/lib/cli_server_example.dart

# Terminal 2
dart run example/lib/cli_client_example.dart
```

### Workflow 2: Development Testing

```bash
# Start server in CLI (easier to see logs)
dart run example/lib/cli_server_example.dart

# Use Flutter app for interactive client testing
flutter run
```

### Workflow 3: Network Discovery

```bash
# Terminal 1 - Start server
dart run example/lib/cli_server_example.dart

# Terminal 2 - Scan for servers
dart run example/lib/cli_scanner_example.dart
```

## Troubleshooting

### **"Server is already running" error**

- Another instance is using the port
- Stop other instances or use a different port

### **"Failed to connect" error**

- Verify server is running
- Check the URL format: `ws://host:port/ws`
- Ensure firewall allows the connection

### **Scanner finds no servers**

- Verify a server is actually running
- Check you're scanning the correct host and port
- For network scanning, ensure devices are on the same network

### **Import errors**

- Run `flutter pub get` in the example directory
- Ensure you're in the correct directory

## Next Steps

After testing these examples:

1. Read the [package README](../README.md) for detailed API documentation
2. Check out the source code in `lib/main.dart` to see how everything works
3. Modify the examples to suit your needs
4. Build your own app using the `local_websocket` package!
