# Flutter Local WebSocket

A pure Dart library for local network WebSocket communication with automatic server discovery and scanning capabilities.

## Features

- 🔍 **Automatic Server Discovery** - Scan local networks to find WebSocket servers
- 🚀 **Easy Server Setup** - Create WebSocket servers with minimal configuration
- 📱 **Client Connection Management** - Simple client connection and messaging
- 🌐 **Cross-Platform** - Works on all Dart platforms (Flutter, CLI, Web)
- 🔧 **Zero Dependencies** - Pure Dart implementation using standard libraries

## Quick Start

### 1. Create a WebSocket Server

```dart
import 'package:flutter_local_websocket/flutter_local_websocket.dart';

void main() async {
  // Create server with custom details
  final server = Server(
    echo: true, // Echo messages back to sender
    details: {
      'name': 'My Local Server',
      'description': 'A local WebSocket server',
      'version': '1.0.0',
    },
  );

  // Start server on localhost:8080
  await server.start(host: '127.0.0.1', port: 8080);
  print('Server running at ${server.address}');

  // Listen for client connections
  server.clientsStream.listen((clients) {
    print('Connected clients: ${clients.length}');
  });
}
```

### 2. Discover Servers on Network

```dart
import 'package:flutter_local_websocket/flutter_local_websocket.dart';

void main() async {
  // Scan localhost for servers on port 8080
  final servers = await Scanner.scan('localhost', port: 8080);
  
  print('Found ${servers.length} servers:');
  for (final server in servers) {
    print('- ${server.path}');
    print('  Details: ${server.details}');
  }
}
```

### 3. Connect and Send Messages

```dart
import 'package:flutter_local_websocket/flutter_local_websocket.dart';

void main() async {
  // Create client
  final client = Client(details: {
    'username': 'john_doe',
    'device': 'mobile',
  });

  // Connect to server
  await client.connect('ws://127.0.0.1:8080/ws');

  // Listen for messages
  client.messageStream.listen((message) {
    print('Received: $message');
  });

  // Send messages
  client.send('Hello, server!');
  client.send({'type': 'chat', 'message': 'Hello from client'});
}
```

## Complete Example

Here's a complete example showing server creation, discovery, and client connection:

```dart
import 'dart:io';
import 'package:flutter_local_websocket/flutter_local_websocket.dart';

void main() async {
  // 1. Start a server
  final server = Server(
    echo: false, // Don't echo back to sender
    details: {
      'name': 'Chat Server',
      'room': 'general',
    },
  );

  await server.start(host: '127.0.0.1', port: 8080);
  print('Server started at ${server.address}');

  // 2. Discover servers on network
  final discoveredServers = await Scanner.scan('localhost');
  print('Found servers: ${discoveredServers.map((s) => s.path)}');

  // 3. Create and connect clients
  final client1 = Client(details: {'username': 'Alice'});
  final client2 = Client(details: {'username': 'Bob'});

  await client1.connect(discoveredServers.first.path);
  await client2.connect(discoveredServers.first.path);

  // 4. Set up message handling
  client1.messageStream.listen((msg) => print('Alice received: $msg'));
  client2.messageStream.listen((msg) => print('Bob received: $msg'));

  // 5. Send messages
  client1.send('Hello from Alice!');
  client2.send('Hi Alice, this is Bob!');

  // Keep running
  await Future.delayed(Duration(seconds: 2));
  
  // Cleanup
  await client1.disconnect();
  await client2.disconnect();
  await server.stop();
}
```

## API Reference

### Server

#### Constructor

```dart
Server({
  bool echo = false,           // Whether to echo messages back to sender
  Map<String, dynamic> details = const {}, // Custom server details
})
```

```dart
// Start server
Future<void> start({required String host, int port = 8080})

// Stop server
Future<void> stop()
```

```dart
Set<Client> clients          // Currently connected clients
Stream<Set<Client>> clientsStream // Stream of client changes
bool isRunning              // Whether server is running
Uri address                 // Server address (when running)
```

### Scanner

```dart
// Scan network for servers
static Future<List<DiscoveredServer>> scan(
  String host,               // Host/subnet to scan (e.g., 'localhost', '192.168.1')
  {int port = 8080}         // Port to scan
)
```

### Client

```dart
Client({
  WebSocketChannel? channel,           // Optional pre-existing channel
  Map<String, String> details = const {}, // Client details/metadata
})
```

```dart
// Connect to server
Future<void> connect(String path)

// Send message
void send(dynamic message)

// Disconnect
Future<void> disconnect()
```

```dart
String uid                  // Unique client identifier
Map<String, String> details // Client details
bool isConnected           // Connection status
Stream<dynamic> messageStream     // Incoming messages
Stream<bool> connectionStream     // Connection status changes
```

### DiscoveredServer

```dart
String path                 // WebSocket connection path
Map<String, dynamic> details // Server details/metadata
```

## Network Scanning

The scanner automatically detects servers by:

1. **HTTP Header Detection** - Looks for `Server: flutter-local-websocket/*` header
2. **Response Validation** - Verifies JSON response format
3. **Subnet Resolution** - Automatically resolves network subnets

### Supported Host Formats

```dart
// Localhost scanning
await Scanner.scan('localhost');       // Scans 127.0.0.*
await Scanner.scan('127.0.0.1');      // Scans 127.0.0.*

// Network subnet scanning  
await Scanner.scan('192.168.1');      // Scans 192.168.1.*
await Scanner.scan('10.0.0');         // Scans 10.0.0.*
```

## Error Handling

```dart
try {
  final server = Server();
  await server.start(host: 'localhost');
  
  final client = Client();
  await client.connect('ws://localhost:8080/ws');
  
} on StateError catch (e) {
  print('State error: $e'); // Server already running, client already connected, etc.
} on ArgumentError catch (e) {
  print('Invalid argument: $e'); // Invalid host format, etc.
} catch (e) {
  print('Network error: $e'); // Connection failed, timeout, etc.
}
```

## Examples

Check out the `/demo` folder for a complete Flutter app example showing:

- Server management UI
- Network scanning interface
- Real-time messaging
- Multiple client handling
