# Local WebSocket

[![Apache 2.0 License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white)](https://dart.dev)

`local_websocket` is a local-first WebSocket library for Flutter and Dart that enables automatic device discovery and real-time communication on a local network (LAN) without cloud servers, static IPs, or manual configuration. It is designed for offline-friendly, zero-config applications where devices need to find and communicate with each other over Wi-Fi or private networks.

This package is useful for Flutter and Dart developers building local network applications such as mobile-to-desktop companion apps, local multiplayer games, classroom or lab tools, kiosk systems, medical or industrial devices, and offline or air-gapped environments. If all participating devices are connected to the same local network, `local_websocket` provides a simple and lightweight solution.

The package combines three core capabilities in a single API: automatic local network discovery, a built-in WebSocket server and client, and real-time messaging using Dart streams. Clients can discover available servers on the local subnet, connect without hardcoded IP addresses, exchange messages in real time, and attach metadata such as device name, role, or user information. The library is written in pure Dart, has zero external dependencies, and works across Flutter and Dart targets including mobile and desktop platforms.

---

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
- [Detailed Guide](#detailed-guide)
  - [Server](#server)
  - [Client](#client)
    - [Auto-Reconnect](#auto-reconnect)
  - [Scanner](#scanner)
  - [Delegates](#delegates)
- [Use Cases](#use-cases)
- [Examples](#examples)
- [Architecture](#architecture)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## Features

- 🔍 **Automatic Server Discovery** - Scan local networks to find WebSocket servers automatically
- 🚀 **Easy Server Setup** - Create WebSocket servers with minimal configuration
- 📱 **Client Connection Management** - Simple client connection and real-time messaging
- 🔄 **Auto-Reconnect** - Automatic reconnection with exponential/linear backoff strategies
- 🌐 **Cross-Platform** - Works on all Dart platforms (Flutter, CLI, Desktop, Server)
- 🔧 **Zero Dependencies** - Pure Dart implementation using only dart:io, dart:async, and dart:convert
- 💬 **Broadcast & Echo Modes** - Choose between broadcasting to all clients or echoing back to sender
- 🏷️ **Metadata Support** - Attach custom details to servers and clients
- 📡 **Real-time Streaming** - Reactive streams for messages, connections, and client updates
- 🆔 **Unique Client IDs** - Automatic unique ID generation for each client
- 🛡️ **Type-Safe** - Fully typed API with Dart's null safety
- 🔐 **Flexible Authentication** - Extensible delegate-based authentication system (token, header, IP-based)
- ✅ **Request & Message Validation** - Validate requests, clients, and messages with custom delegates
- 🔌 **Connection Lifecycle Hooks** - Handle client connection and disconnection events
- ⚡ **Lightweight** - No external dependencies means smaller package size and faster installation

---

## Installation

Add `local_websocket` to your `pubspec.yaml`:

```yaml
dependencies:
  local_websocket: ^0.0.2
```

Then run:

```bash
dart pub get
```

Or for Flutter projects:

```bash
flutter pub get
```

---

## Quick Start

### 1. Create a WebSocket Server

```dart
import 'package:local_websocket/local_websocket.dart';

void main() async {
  // Create server with custom details
  final server = Server(
    echo: false, // Broadcast mode: messages go to all OTHER clients
    details: {
      'name': 'My Local Server',
      'description': 'A local WebSocket server',
    },
  );

  // Start server on localhost:8080
  await server.start('127.0.0.1', port: 8080);
  print('Server running at ${server.address}');

  // Listen for client connections
  server.clientsStream.listen((clients) {
    print('Connected clients: ${clients.length}');
  });
}
```

### 2. Discover Servers on Network

```dart
import 'package:local_websocket/local_websocket.dart';

void main() async {
  // Scan localhost for servers on port 8080
  // Returns a Stream that continuously scans every 3 seconds
  await for (final servers in Scanner.scan('localhost', port: 8080)) {
    print('Found ${servers.length} servers:');
    for (final server in servers) {
      print('- ${server.path}');
      print('  Details: ${server.details}');
    }
  }
}
```

### 3. Connect Client and Send Messages

```dart
import 'package:local_websocket/local_websocket.dart';

void main() async {
  // Create client with metadata
  final client = Client(
    details: {
      'username': 'john_doe',
      'device': 'mobile',
    },
  );

  // Connect to server
  await client.connect('ws://127.0.0.1:8080/ws');
  print('Connected! Client ID: ${client.uid}');

  // Listen for messages
  client.messageStream.listen((message) {
    print('Received: $message');
  });

  // Listen for connection changes
  client.connectionStream.listen((isConnected) {
    print('Connection status: ${isConnected ? "Connected" : "Disconnected"}');
  });

  // Send messages (supports String, Map, List, etc.)
  client.send('Hello, server!');
  client.send({'type': 'chat', 'message': 'Hello from client'});
  client.send(['data', 123, true]);
  
  // Disconnect when done
  await Future.delayed(Duration(seconds: 5));
  await client.disconnect();
}
```

---

## Core Concepts

### Server

The **Server** is the central hub that accepts WebSocket connections and manages message routing between clients. It runs on a specified host and port, provides server information via HTTP, and handles WebSocket connections.

**Two Messaging Modes:**

- **Broadcast Mode** (`echo: false`): Messages from one client are sent to all OTHER clients (sender doesn't receive their own message)
- **Echo Mode** (`echo: true`): Messages from one client are sent to ALL clients including the sender

### Client

The **Client** connects to a server via WebSocket and can send/receive messages in real-time. Each client has a unique ID (timestamp-based) and can include custom metadata (username, device type, etc.) that gets passed to the server as query parameters.

### Scanner

The **Scanner** automatically discovers servers on the local network by scanning IP addresses in a subnet. It checks each IP for the server's HTTP endpoint and validates it's a `local-websocket` server by checking the `Server` header.

### DiscoveredServer

A simple model representing a discovered server with:

- `path`: The WebSocket URL (e.g., `ws://192.168.1.100:8080/ws`)
- `details`: The server's metadata (returned from the HTTP endpoint)

---

## Detailed Guide

### Server

#### Creating a Server

```dart
final server = Server(
  echo: false, // Broadcast mode
  details: {
    'name': 'Game Server',
    'maxPlayers': 4,
    'gameType': 'multiplayer',
  },
  // Optional: Add authentication
  requestAuthenticationDelegate: RequestTokenAuthenticator(
    validTokens: {'secret123', 'secret456'},
  ),
  // Optional: Handle client connections
  clientConnectionDelegate: MyConnectionHandler(),
);
```

#### Starting the Server

```dart
// Start on localhost (127.0.0.1)
await server.start('127.0.0.1', port: 8080);

// Start on all network interfaces (0.0.0.0)
await server.start('0.0.0.0', port: 8080);

// Start on specific IP address
await server.start('192.168.1.100', port: 9000);
```

**Important:**

- `127.0.0.1` (localhost): Only accessible from the same machine
- `0.0.0.0`: Accessible from any network interface
- Specific IP: Accessible via that IP address

#### Server Properties

```dart
server.isConnected;      // bool: Is server running?
server.address;          // Uri: Server address (throws if not running)
server.clients;          // Set<Client>: Currently connected clients
server.clientsStream;    // Stream<Set<Client>>: Stream of client changes
server.connectionStream; // Stream<bool>: Stream of server connection status
server.messageStream;    // Stream<dynamic>: Stream of all messages received
```

#### Sending Messages from Server

```dart
// Send to all connected clients
server.send('Server announcement!');
server.send({'type': 'notification', 'message': 'New player joined'});
```

#### Stopping the Server

```dart
await server.stop();
// Automatically disconnects all clients
```

#### Server HTTP Endpoint

When running, the server provides an HTTP endpoint at the root path (`/`) that returns server details as JSON:

```bash
curl http://127.0.0.1:8080/
# Response: {"name":"Game Server","maxPlayers":4,"gameType":"multiplayer"}
```

This endpoint includes a custom header: `Server: local-websocket/1.0.0`, which the Scanner uses for discovery.

---

### Client

#### Creating a Client

```dart
final client = Client(
  details: {
    'username': 'Alice',
    'deviceType': 'iOS',
    'appVersion': '1.0.0',
  },
);
```

**Note:** The `details` map values must be `String` type. They're passed to the server as query parameters.

#### Connecting to a Server

```dart
// Connect using discovered server
final servers = await Scanner.scan('localhost').first;
await client.connect(servers.first.path);

// Or connect directly
await client.connect('ws://127.0.0.1:8080/ws');
```

The client details are automatically added as query parameters:

```txt
ws://127.0.0.1:8080/ws?username=Alice&deviceType=iOS&appVersion=1.0.0
```

#### Client Properties

```dart
client.uid;              // String: Unique ID for this client (timestamp-based)
client.details;          // Map<String, String>: Client metadata (unmodifiable)
client.isConnected;      // bool: Is client connected?
client.messageStream;    // Stream<dynamic>: Incoming messages
client.connectionStream; // Stream<bool>: Connection status changes
```

#### Sending Messages

```dart
// Send string
client.send('Hello!');

// Send JSON-encodable data
client.send({'action': 'move', 'x': 10, 'y': 20});

// Send list
client.send([1, 2, 3, 4, 5]);
```

#### Receiving Messages

```dart
client.messageStream.listen((message) {
  // Messages arrive as dynamic - cast as needed
  if (message is String) {
    print('Text message: $message');
  } else if (message is Map) {
    print('JSON message: $message');
  }
});
```

#### Monitoring Connection Status

```dart
client.connectionStream.listen((isConnected) {
  if (isConnected) {
    print('Connected to server');
  } else {
    print('Disconnected from server');
  }
});
```

#### Disconnecting

```dart
await client.disconnect();
```

#### Auto-Reconnect

The client supports automatic reconnection when the connection is lost unexpectedly. Enable it by providing a `ClientReconectionDelegate`:

```dart
final client = Client(
  details: {'username': 'Alice'},
  clientReconnectionDelegate: ExponentialBackoffReconnect(
    maxAttempts: 5,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 30),
    multiplier: 2.0,
  ),
);

await client.connect('ws://127.0.0.1:8080/ws');
// If connection is lost, client will automatically try to reconnect
// with exponential backoff: 1s, 2s, 4s, 8s, 16s (capped at 30s)
```

**Built-in Reconnection Strategies:**

1. **ExponentialBackoffReconnect** - Exponentially increasing delays (1s, 2s, 4s, 8s...)
   ```dart
   ExponentialBackoffReconnect(
     maxAttempts: 5,              // Stop after 5 failed attempts
     initialDelay: Duration(seconds: 1),
     maxDelay: Duration(seconds: 30),
     multiplier: 2.0,
   )
   ```

2. **LinearBackoffReconnect** - Linearly increasing delays (2s, 4s, 6s, 8s...)
   ```dart
   LinearBackoffReconnect(
     maxAttempts: 10,             // Stop after 10 failed attempts
     interval: Duration(seconds: 2),
   )
   ```

3. **InfiniteReconnect** - Never gives up, keeps trying forever
   ```dart
   InfiniteReconnect(
     interval: Duration(seconds: 5),  // Try every 5 seconds
   )
   ```

**Connection Status Tracking:**

Monitor the connection status to show UI feedback:

```dart
client.connectionStream.listen((status) {
  switch (status) {
    case ClientConnectionStatus.connected:
      print('✅ Connected');
      break;
    case ClientConnectionStatus.connecting:
      print('⏳ Connecting... (auto-reconnect in progress)');
      break;
    case ClientConnectionStatus.disconnected:
      print('❌ Disconnected');
      break;
  }
});

// Or check current status
if (client.connectionStatus == ClientConnectionStatus.connected) {
  client.send('Hello!');
}
```

**Custom Reconnection Logic:**

Create your own reconnection strategy:

```dart
class SmartReconnect implements ClientReconectionDelegate {
  @override
  Future<bool> shouldReconnect(int attemptNumber, Duration timeSinceLastConnect) async {
    // Only reconnect during business hours
    final hour = DateTime.now().hour;
    if (hour < 9 || hour > 17) return false;
    
    return attemptNumber < 3;
  }
  
  @override
  Future<Duration> getReconnectDelay(int attemptNumber) async {
    return Duration(seconds: 5);
  }
  
  @override
  void onReconnected(int attemptNumber) {
    print('Successfully reconnected!');
  }
  
  @override
  void onReconnectFailed(int totalAttempts) {
    print('Failed to reconnect after $totalAttempts attempts');
  }
}

final client = Client(
  clientReconnectionDelegate: SmartReconnect(),
);
```

---

### Scanner

#### Basic Scanning

```dart
// Scan localhost continuously (every 3 seconds)
await for (final servers in Scanner.scan('localhost')) {
  print('Found ${servers.length} servers');
}
```

#### Scanning a Subnet

```dart
// Scan 192.168.1.0-255 subnet on port 8080
await for (final servers in Scanner.scan('192.168.1')) {
  for (final server in servers) {
    print('Server at ${server.path}');
    print('Details: ${server.details}');
  }
}
```

#### Custom Port and Interval

```dart
// Scan every 5 seconds on port 9000
await for (final servers in Scanner.scan(
  '192.168.1',
  port: 9000,
  interval: Duration(seconds: 5),
)) {
  // Handle discovered servers
}
```

#### One-Time Scan

```dart
// Get first scan result and stop
final servers = await Scanner.scan('localhost').first;
print('Found ${servers.length} servers');
```

#### Scanner Parameters

```dart
Scanner.scan(
  String host,              // 'localhost', '127.0.0.1', or '192.168.1'
  {
    int port = 8080,        // Port to scan
    Duration interval = const Duration(seconds: 3), // Scan interval
    String type = 'local-websocket', // Server type identifier
  }
)
```

**Host Formats:**

- `'localhost'` or `'127.0.0.1'`: Scans `127.0.0.0-255`
- `'192.168.1'`: Scans `192.168.1.0-255`
- Must be at least 3 parts when using IP format

---

## Delegates

The package provides a powerful delegate system for customizing server behavior. Delegates allow you to add authentication, validation, and event handling without modifying the core server logic.

### Overview

There are four types of delegates:

1. **RequestAuthenticationDelegate** - Authenticate HTTP requests before WebSocket upgrade
2. **ClientValidationDelegate** - Validate clients after WebSocket connection established
3. **ClientConnectionDelegate** - Handle client connection/disconnection events
4. **MessageValidationDelegate** - Validate individual messages from clients

### RequestAuthenticationDelegate

Authenticates incoming HTTP requests **before** the WebSocket upgrade occurs. This is your first line of defense for security.

#### Interface

```dart
abstract interface class RequestAuthenticationDelegate {
  FutureOr<RequestAuthenticationResult> authenticateRequest(HttpRequest request);
}
```

#### Built-in Authenticators

##### 1. RequestTokenAuthenticator

Validates a token passed as a query parameter:

```dart
final server = Server(
  requestAuthenticationDelegate: RequestTokenAuthenticator(
    validTokens: {'secret123', 'admin_token', 'user_pass'},
    parameterName: 'token', // Default parameter name
  ),
);
```

Clients must include the token in the connection URL:

```dart
await client.connect('ws://127.0.0.1:8080/ws?token=secret123');
```

Or use the `details` parameter:

```dart
final client = Client(details: {'token': 'secret123'});
await client.connect('ws://127.0.0.1:8080/ws');
```

##### 2. RequestHeaderAuthenticator

Validates HTTP headers (useful for authorization tokens):

```dart
final server = Server(
  requestAuthenticationDelegate: RequestHeaderAuthenticator(
    headerName: 'Authorization',
    validValues: {'Bearer secret123', 'Bearer admin_token'},
    caseSensitive: true, // Default is true
  ),
);
```

**Note:** WebSocket clients from browsers cannot set custom headers during initial handshake. This is best used for server-to-server communication or non-browser clients.

##### 3. RequestIPAuthenticator

Restricts access based on IP address whitelist:

```dart
final server = Server(
  requestAuthenticationDelegate: RequestIPAuthenticator(
    allowedIPs: {
      '127.0.0.1',      // Localhost
      '192.168.1.100',  // Specific device
      '10.0.0.50',      // Another device
    },
  ),
);
```

##### 4. MultiRequestAuthenticator

Combines multiple authenticators - **all must pass**:

```dart
final server = Server(
  requestAuthenticationDelegate: MultiRequestAuthenticator([
    RequestTokenAuthenticator(validTokens: {'secret123'}),
    RequestIPAuthenticator(allowedIPs: {'127.0.0.1', '192.168.1.100'}),
  ]),
);
```

In this example, clients must provide a valid token **AND** connect from an allowed IP.

#### Custom Authentication

Create your own authenticator by implementing the interface:

```dart
class CustomAuthenticator implements RequestAuthenticationDelegate {
  final String apiKey;
  
  const CustomAuthenticator({required this.apiKey});
  
  @override
  Future<RequestAuthenticationResult> authenticateRequest(HttpRequest request) async {
    final providedKey = request.url.queryParameters['api_key'];
    
    if (providedKey == null) {
      return RequestAuthenticationResult.failure(
        reason: 'Missing API key',
        statusCode: 401,
      );
    }
    
    // Validate against database, external API, etc.
    final isValid = await validateApiKey(providedKey);
    
    if (!isValid) {
      return RequestAuthenticationResult.failure(
        reason: 'Invalid API key',
        statusCode: 403,
      );
    }
    
    return RequestAuthenticationResult.success(
      metadata: {'apiKey': providedKey},
    );
  }
  
  Future<bool> validateApiKey(String key) async {
    // Your validation logic here
    return key == apiKey;
  }
}

// Usage
final server = Server(
  requestAuthenticationDelegate: CustomAuthenticator(apiKey: 'my-secret-key'),
);
```

#### RequestAuthenticationResult

The result object provides factory methods for common responses:

```dart
// Success - allow connection
RequestAuthenticationResult.success(metadata: {'user': 'john'});

// Success - simple allow
RequestAuthenticationResult.allow();

// Failure - custom reason and status code
RequestAuthenticationResult.failure(
  reason: 'Invalid credentials',
  statusCode: 403,
);

// Failure - simple deny
RequestAuthenticationResult.deny();
```

### ClientValidationDelegate

Validates clients **after** the WebSocket connection is established but **before** they're added to the active clients list.

#### Interface

```dart
abstract class ClientValidationDelegate {
  FutureOr<bool> validateClient(Client client, HttpRequest request);
}
```

#### Use Cases

- Check if client details are valid
- Enforce maximum client limits
- Validate client metadata
- Check client against database

#### Example: Limit Maximum Clients

```dart
class MaxClientsValidator implements ClientValidationDelegate {
  final int maxClients;
  final Server server;
  
  MaxClientsValidator({required this.maxClients, required this.server});
  
  @override
  Future<bool> validateClient(Client client, HttpRequest request) async {
    if (server.clients.length >= maxClients) {
      print('Server full: ${server.clients.length}/$maxClients');
      return false;
    }
    return true;
  }
}

// Usage
final server = Server();
server.clientValidationDelegate = MaxClientsValidator(
  maxClients: 10,
  server: server,
);
```

#### Example: Require Username

```dart
class UsernameValidator implements ClientValidationDelegate {
  @override
  Future<bool> validateClient(Client client, HttpRequest request) async {
    final username = client.details['username'];
    
    if (username == null || username.isEmpty) {
      print('Client rejected: missing username');
      return false;
    }
    
    if (username.length < 3) {
      print('Client rejected: username too short');
      return false;
    }
    
    return true;
  }
}

// Usage
final server = Server(
  clientValidationDelegate: UsernameValidator(),
);

// Client must provide username
final client = Client(details: {'username': 'Alice'});
await client.connect('ws://127.0.0.1:8080/ws');
```

### ClientConnectionDelegate

Handles client connection and disconnection events. Perfect for logging, analytics, or triggering side effects.

#### Interface

```dart
abstract interface class ClientConnectionDelegate {
  FutureOr<void> onClientConnected(Client client);
  FutureOr<void> onClientDisconnected(Client client);
}
```

#### Example: Connection Logging

```dart
class ConnectionLogger implements ClientConnectionDelegate {
  @override
  Future<void> onClientConnected(Client client) async {
    print('✅ Client connected: ${client.uid}');
    print('   Details: ${client.details}');
    
    // Log to database, send analytics, etc.
    await logConnection(client.uid, client.details);
  }
  
  @override
  Future<void> onClientDisconnected(Client client) async {
    print('❌ Client disconnected: ${client.uid}');
    
    // Cleanup, save state, etc.
    await cleanupClientData(client.uid);
  }
  
  Future<void> logConnection(String uid, Map<String, String> details) async {
    // Your logging logic
  }
  
  Future<void> cleanupClientData(String uid) async {
    // Your cleanup logic
  }
}

// Usage
final server = Server(
  clientConnectionDelegate: ConnectionLogger(),
);
```

#### Example: Broadcast Join/Leave Messages

```dart
class JoinLeaveAnnouncer implements ClientConnectionDelegate {
  final Server server;
  
  JoinLeaveAnnouncer({required this.server});
  
  @override
  Future<void> onClientConnected(Client client) async {
    final username = client.details['username'] ?? 'Anonymous';
    server.send({
      'type': 'user_joined',
      'username': username,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  @override
  Future<void> onClientDisconnected(Client client) async {
    final username = client.details['username'] ?? 'Anonymous';
    server.send({
      'type': 'user_left',
      'username': username,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}

// Usage
final server = Server();
server.clientConnectionDelegate = JoinLeaveAnnouncer(server: server);
```

### MessageValidationDelegate

Validates individual messages from clients before broadcasting. This is useful for content filtering, rate limiting, or message format validation.

#### Interface

```dart
abstract class MessageValidationDelegate {
  FutureOr<bool> validateMessage(Client client, String message);
}
```

#### Example: Profanity Filter

```dart
class ProfanityFilter implements MessageValidationDelegate {
  final Set<String> bannedWords = {'badword1', 'badword2'};
  
  @override
  Future<bool> validateMessage(Client client, String message) async {
    final lowerMessage = message.toString().toLowerCase();
    
    for (final word in bannedWords) {
      if (lowerMessage.contains(word)) {
        print('Blocked message from ${client.uid}: contains profanity');
        return false;
      }
    }
    
    return true;
  }
}

// Usage
final server = Server(
  messageValidationDelegate: ProfanityFilter(),
);
```

#### Example: Rate Limiting

```dart
class RateLimiter implements MessageValidationDelegate {
  final Map<String, List<DateTime>> _messageTimes = {};
  final int maxMessages;
  final Duration timeWindow;
  
  RateLimiter({
    this.maxMessages = 10,
    this.timeWindow = const Duration(seconds: 10),
  });
  
  @override
  Future<bool> validateMessage(Client client, String message) async {
    final now = DateTime.now();
    final clientId = client.uid;
    
    // Initialize or get message times for this client
    _messageTimes.putIfAbsent(clientId, () => []);
    
    // Remove old messages outside time window
    _messageTimes[clientId]!.removeWhere(
      (time) => now.difference(time) > timeWindow,
    );
    
    // Check if limit exceeded
    if (_messageTimes[clientId]!.length >= maxMessages) {
      print('Rate limit exceeded for ${client.uid}');
      return false;
    }
    
    // Add this message
    _messageTimes[clientId]!.add(now);
    return true;
  }
}

// Usage
final server = Server(
  messageValidationDelegate: RateLimiter(
    maxMessages: 5,
    timeWindow: Duration(seconds: 10),
  ),
);
```

#### Example: Message Format Validation

```dart
class MessageFormatValidator implements MessageValidationDelegate {
  @override
  Future<bool> validateMessage(Client client, String message) async {
    // Expecting JSON messages
    try {
      final decoded = jsonDecode(message);
      
      if (decoded is! Map) {
        print('Invalid message format: not a map');
        return false;
      }
      
      if (!decoded.containsKey('type')) {
        print('Invalid message format: missing type field');
        return false;
      }
      
      return true;
    } catch (e) {
      print('Invalid message format: not valid JSON');
      return false;
    }
  }
}

// Usage
final server = Server(
  messageValidationDelegate: MessageFormatValidator(),
);
```

### Combining Multiple Delegates

You can use all delegates together for comprehensive control:

```dart
final server = Server(
  echo: false,
  details: {'name': 'Secure Chat Server'},
  
  // 1. Authenticate requests
  requestAuthenticationDelegate: MultiRequestAuthenticator([
    RequestTokenAuthenticator(validTokens: {'secret123'}),
    RequestIPAuthenticator(allowedIPs: {'127.0.0.1'}),
  ]),
  
  // 2. Validate clients
  clientValidationDelegate: UsernameValidator(),
  
  // 3. Handle connections
  clientConnectionDelegate: JoinLeaveAnnouncer(server: server),
  
  // 4. Validate messages
  messageValidationDelegate: MultiMessageValidator([
    ProfanityFilter(),
    RateLimiter(maxMessages: 5, timeWindow: Duration(seconds: 10)),
    MessageFormatValidator(),
  ]),
);
```

**Note:** Create a `MultiMessageValidator` similar to `MultiRequestAuthenticator` if you need to combine multiple message validators.

### Delegate Execution Order

When a client attempts to connect, delegates are executed in this order:

1. **RequestAuthenticationDelegate** - Before WebSocket upgrade
   - If fails: Returns HTTP 401/403, connection rejected

2. **WebSocket Upgrade** - Connection established

3. **ClientValidationDelegate** - After connection, before adding to clients
   - If fails: WebSocket closed with code 1008, client not added

4. **Client Added** - Client joins the active clients set

5. **ClientConnectionDelegate.onClientConnected** - After client added
   - Runs asynchronously, doesn't block

6. **Message Loop** - For each message:
   - **MessageValidationDelegate** - Validate message
   - If valid: Broadcast to clients
   - If invalid: Silently drop message

7. **On Disconnect**:
   - **ClientConnectionDelegate.onClientDisconnected** - Cleanup
   - Runs asynchronously, doesn't block

### Security Best Practices

1. **Always use RequestAuthenticationDelegate** for authentication (happens before WebSocket upgrade)
2. **Use ClientValidationDelegate** for business logic validation (max clients, metadata checks)
3. **Use MessageValidationDelegate** for content filtering and rate limiting
4. **Use HTTPS/WSS in production** - These delegates don't replace transport security
5. **Validate all input** - Don't trust client data
6. **Log authentication failures** - Monitor for attacks
7. **Use IP whitelisting carefully** - IPs can be spoofed on some networks

---

## Use Cases

### 1. **Local Multiplayer Games**

Create real-time multiplayer games where players on the same WiFi network can discover and join games.

```dart
// Game host creates server
final server = Server(details: {'gameName': 'Chess Match', 'players': 0});
await server.start('0.0.0.0');

// Players scan and join
final games = await Scanner.scan('192.168.1').first;
final client = Client(details: {'playerName': 'Alice'});
await client.connect(games.first.path);
```

### 2. **LAN Chat Application**

Build a local chat room for devices on the same network.

```dart
// Chat server
final server = Server(echo: false, details: {'room': 'General'});
server.messageStream.listen((msg) => print('Message: $msg'));

// Chat client
final client = Client(details: {'username': 'Bob'});
client.messageStream.listen((msg) => print('New message: $msg'));
client.send('Hello everyone!');
```

### 3. **Device Synchronization**

Sync data between multiple devices without cloud services.

```dart
// Device A (server)
final serverDevice = Server(details: {'deviceName': 'Desktop'});
await serverDevice.start('0.0.0.0');

// Device B (client)
final clientDevice = Client(details: {'deviceName': 'Laptop'});
await clientDevice.connect(discoveredServer.path);
clientDevice.send({'syncData': [...]}); // Share data
```

### 4. **IoT Device Discovery**

Discover and communicate with IoT devices on the local network.

```dart
// IoT device runs server
final iotServer = Server(details: {
  'deviceType': 'SmartLight',
  'firmwareVersion': '2.0.1',
});

// Control app scans for devices
await for (final devices in Scanner.scan('192.168.1')) {
  for (final device in devices) {
    if (device.details['deviceType'] == 'SmartLight') {
      // Connect and control
    }
  }
}
```

### 5. **File Sharing**

Share files between devices on the same network.

```dart
// Sender
final sender = Server(details: {'sharing': 'documents.pdf'});
server.messageStream.listen((request) {
  // Send file chunks
  server.send(fileData);
});

// Receiver
final receiver = Client();
receiver.messageStream.listen((chunk) {
  // Receive and reconstruct file
});
```

### 6. **Resilient Mobile App**

Build a mobile app that maintains connection despite network issues.

```dart
// Mobile client with auto-reconnect
final client = Client(
  details: {'userId': '12345', 'deviceType': 'mobile'},
  clientReconnectionDelegate: ExponentialBackoffReconnect(
    maxAttempts: 10,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 60),
  ),
);

await client.connect('ws://192.168.1.100:8080/ws');

// Monitor connection status for UI feedback
client.connectionStream.listen((status) {
  if (status == ClientConnectionStatus.connecting) {
    showSnackBar('Reconnecting...');
  } else if (status == ClientConnectionStatus.connected) {
    showSnackBar('Connected!');
  }
});

// Client will automatically reconnect if WiFi drops or server restarts
```

---

## Examples

### Complete Chat Application

```dart
import 'package:local_websocket/local_websocket.dart';

void main() async {
  print('Choose mode: (1) Server or (2) Client');
  // In real app, get user input
  final mode = 1; // Example: server mode
  
  if (mode == 1) {
    // Server mode
    final server = Server(
      echo: false,
      details: {'chatRoom': 'Main Lobby'},
    );
    
    await server.start('0.0.0.0', port: 8080);
    print('Chat server started at ${server.address}');
    
    server.clientsStream.listen((clients) {
      print('Users online: ${clients.length}');
    });
    
    server.messageStream.listen((message) {
      print('Message received: $message');
    });
    
  } else {
    // Client mode
    print('Scanning for chat servers...');
    final servers = await Scanner.scan('192.168.1').first;
    
    if (servers.isEmpty) {
      print('No servers found');
      return;
    }
    
    final client = Client(details: {'username': 'Alice'});
    await client.connect(servers.first.path);
    print('Connected to chat!');
    
    client.messageStream.listen((message) {
      print('Message: $message');
    });
    
    // Send messages
    client.send('Hello everyone!');
  }
}
```

### Real-time Game Example

```dart
import 'package:local_websocket/local_websocket.dart';

class GameServer {
  final server = Server(
    echo: false,
    details: {
      'gameName': 'Tic Tac Toe',
      'maxPlayers': 2,
      'status': 'waiting',
    },
  );
  
  Future<void> start() async {
    await server.start('0.0.0.0', port: 8080);
    
    server.messageStream.listen((message) {
      if (message is Map) {
        handleGameAction(message);
      }
    });
  }
  
  void handleGameAction(Map action) {
    // Process game logic
    final response = {'type': 'gameUpdate', 'board': [...]};
    server.send(response); // Broadcast to all players
  }
}

class GameClient {
  final client = Client(details: {'playerName': 'Bob'});
  
  Future<void> join() async {
    final games = await Scanner.scan('192.168.1').first;
    final gameServer = games.firstWhere(
      (s) => s.details['gameName'] == 'Tic Tac Toe',
    );
    
    await client.connect(gameServer.path);
    
    client.messageStream.listen((message) {
      if (message is Map && message['type'] == 'gameUpdate') {
        updateGameBoard(message['board']);
      }
    });
  }
  
  void makeMove(int x, int y) {
    client.send({'type': 'move', 'x': x, 'y': y});
  }
  
  void updateGameBoard(dynamic board) {
    // Update UI
  }
}
```

---

## Architecture

### Zero-Dependency Implementation

This package is built using **only Dart SDK libraries** with zero external dependencies:

- **`dart:io`** - HTTP server, WebSocket protocol, network operations
- **`dart:async`** - Streams, futures, and async operations  
- **`dart:convert`** - JSON encoding/decoding

**Benefits:**

- ✅ Smaller package size (~50KB vs typical 2MB+ with dependencies)
- ✅ Faster installation and pub get
- ✅ No dependency conflicts
- ✅ Direct control over WebSocket implementation
- ✅ Works everywhere Dart runs without platform-specific code

### How It Works

```
┌─────────────────┐
│     Server      │
│  (0.0.0.0:8080) │
└────────┬────────┘
         │
         │  HTTP GET /  → Returns server details (JSON)
         │  WS /ws      → WebSocket endpoint
         │
    ┌────┴────┐
    │         │
┌───▼───┐ ┌──▼────┐
│Client1│ │Client2│
└───────┘ └───────┘
```

**Server Responsibilities:**

1. Listen for HTTP requests at `/` (returns server details)
2. Accept WebSocket connections at `/ws`
3. Manage connected clients
4. Route messages between clients (broadcast or echo)
5. Emit streams for clients, connections, and messages

**Client Responsibilities:**

1. Connect to server's WebSocket endpoint
2. Send messages to server
3. Receive messages from server
4. Emit streams for messages and connection status
5. Include metadata via query parameters

**Scanner Responsibilities:**

1. Generate IP addresses in subnet range
2. Send HTTP GET requests to each IP
3. Check `Server` header for `local-websocket`
4. Parse response JSON for server details
5. Return list of discovered servers
6. Repeat scan at specified intervals

---

## Best Practices

### 1. **Error Handling**

Always wrap server/client operations in try-catch:

```dart
try {
  await server.start('0.0.0.0', port: 8080);
} catch (e) {
  print('Failed to start server: $e');
}

try {
  await client.connect('ws://127.0.0.1:8080/ws');
} catch (e) {
  print('Failed to connect: $e');
}
```

### 2. **Resource Cleanup**

Always clean up resources when done:

```dart
// Stop server
await server.stop();

// Disconnect clients
await client.disconnect();

// Cancel stream subscriptions
subscription.cancel();
```

### 3. **Message Validation**

Validate incoming messages:

```dart
client.messageStream.listen((message) {
  if (message is! Map) {
    print('Invalid message format');
    return;
  }
  
  if (!message.containsKey('type')) {
    print('Message missing type field');
    return;
  }
  
  // Process valid message
});
```

### 4. **Connection State Management**

Track connection state:

```dart
bool isConnected = false;

client.connectionStream.listen((connected) {
  isConnected = connected;
  if (!connected) {
    // Handle disconnection, try reconnect
  }
});
```

### 5. **Scanning Optimization**

Don't scan continuously if you don't need to:

```dart
// One-time scan
final servers = await Scanner.scan('192.168.1').first;

// Limited scanning
final subscription = Scanner.scan('192.168.1').listen((servers) {
  if (servers.isNotEmpty) {
    subscription.cancel(); // Stop scanning once found
  }
});
```

### 6. **Server Details Best Practices**

Include useful metadata:

```dart
final server = Server(
  details: {
    'name': 'My Server',
    'version': '1.0.0',
    'maxClients': 10,
    'requiresAuth': false,
    'description': 'A friendly server',
  },
);
```

---

## Troubleshooting

### Problem: Scanner doesn't find any servers

**Solutions:**

1. Verify server is running: Check `server.isConnected`
2. Check firewall: Ensure port is not blocked
3. Verify correct subnet: Use `ipconfig` (Windows) or `ifconfig` (Mac/Linux) to find your subnet
4. Check port: Ensure scanner and server use the same port
5. Wait longer: Scanner needs time to check all IPs

```dart
// Debug: Check if server is accessible via HTTP
final response = await http.get(Uri.parse('http://127.0.0.1:8080/'));
print(response.body); // Should print server details
```

### Problem: Client can't connect

**Solutions:**

1. Verify WebSocket URL format: Must start with `ws://`
2. Check server address: Use IP address instead of hostname
3. Ensure server is running on correct interface (use `0.0.0.0` for all interfaces)

```dart
// Correct format
await client.connect('ws://192.168.1.100:8080/ws');

// Incorrect formats
await client.connect('http://192.168.1.100:8080/ws'); // Wrong scheme
await client.connect('192.168.1.100:8080/ws'); // Missing scheme
```

### Problem: Messages not being received

**Solutions:**

1. Check echo mode: If `echo: false`, sender won't receive their own messages
2. Verify message format: Ensure messages are JSON-encodable
3. Check stream subscriptions: Ensure you're listening to `messageStream`

```dart
// Always listen BEFORE sending
client.messageStream.listen((msg) => print(msg));
await Future.delayed(Duration(milliseconds: 100)); // Let subscription establish
client.send('Hello');
```

### Problem: StateError when starting/stopping

**Solutions:**

1. Don't start an already running server
2. Don't stop an already stopped server
3. Check `isConnected` before operations

```dart
if (!server.isConnected) {
  await server.start('0.0.0.0');
}

if (server.isConnected) {
  await server.stop();
}
```

### Problem: Port already in use

**Solutions:**

1. Use different port
2. Stop other application using the port
3. Wait a few seconds after stopping server before restarting

```dart
await server.start('0.0.0.0', port: 8081); // Try different port
```

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## Author

Created by Ehsan Rashidi

---

## Support

If you find this package helpful, please give it a ⭐️ on GitHub!

### DiscoveredServer

```dart
String path                 // WebSocket connection path
Map<String, dynamic> details // Server details/metadata
```

## Network Scanning

The scanner automatically detects servers by:

1. **HTTP Header Detection** - Looks for `Server: local-websocket/*` header
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

The package uses a structured error model with `WebSocketError` for consistent error handling.

### WebSocketError

All connection and authentication errors are wrapped in a `WebSocketError` that provides:

- **`code`**: Error category (`'AUTHENTICATION_FAILED'`, `'CONNECTION_FAILED'`, `'VALIDATION_FAILED'`)
- **`message`**: Human-readable error description
- **`statusCode`**: HTTP status code when applicable (401, 403, etc.)
- **`details`**: Additional error metadata
- **`originalError`**: Underlying exception for debugging

### Client Connection Errors

```dart
try {
  final client = Client(details: {'token': 'secret123'});
  await client.connect('ws://127.0.0.1:8080/ws');
  
} on WebSocketError catch (e) {
  if (e.code == 'AUTHENTICATION_FAILED') {
    if (e.statusCode == 401) {
      print('Authentication required: ${e.message}');
      // Prompt user for credentials
    } else if (e.statusCode == 403) {
      print('Invalid credentials: ${e.message}');
      // Show error message to user
    }
  } else if (e.code == 'VALIDATION_FAILED') {
    print('Connection rejected: ${e.message}');
    // Handle validation failure (e.g., banned client)
  } else if (e.code == 'CONNECTION_FAILED') {
    print('Connection failed: ${e.message}');
    // Check network, server address, etc.
  }
} catch (e) {
  print('Unexpected error: $e');
}
```

### Server Errors

```dart
try {
  final server = Server();
  await server.start('0.0.0.0', port: 8080);
  
} on StateError catch (e) {
  print('State error: $e'); 
  // Server already running
  
} on SocketException catch (e) {
  print('Socket error: $e'); 
  // Port already in use, invalid host, etc.
  
} catch (e) {
  print('Network error: $e');
}
```

### Common Error Scenarios

#### Authentication Failures

```dart
// HTTP 401 - Missing credentials
WebSocketError: [AUTHENTICATION_FAILED] Authentication required (HTTP 401)

// HTTP 403 - Invalid credentials
WebSocketError: [AUTHENTICATION_FAILED] Invalid token (HTTP 403)
```

#### Connection Failures

```dart
// Network unreachable
WebSocketError: [CONNECTION_FAILED] Connection failed: Network unreachable

// Server not responding
WebSocketError: [CONNECTION_FAILED] Connection timeout
```

#### Validation Failures

```dart
// Client validation failed
WebSocketError: [VALIDATION_FAILED] Maximum clients reached

// Message validation failed (silently dropped by server)
```
