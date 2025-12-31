import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:local_websocket/local_websocket.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

// ===== CUSTOM DELEGATES =====

/// Example implementation of ClientConnectionDelegate
/// Logs when clients connect and disconnect
class LoggingConnectionDelegate implements ClientConnectionDelegate {
  final void Function(String) onLog;

  const LoggingConnectionDelegate(this.onLog);

  @override
  Future<void> onClientConnected(Client client) async {
    onLog('Client connected: ${client.uid}');
    if (client.details.isNotEmpty) {
      onLog('  Details: ${client.details}');
    }
  }

  @override
  Future<void> onClientDisconnected(Client client) async {
    onLog('Client disconnected: ${client.uid}');
  }
}

/// Example implementation of RequestAuthenticationDelegate
/// Requires a token in the query parameters
class SimpleTokenAuthenticator implements RequestAuthenticationDelegate {
  final String requiredToken;
  final void Function(String)? onLog;

  const SimpleTokenAuthenticator({
    required this.requiredToken,
    this.onLog,
  });

  @override
  Future<RequestAuthenticationResult> authenticateRequest(HttpRequest request) async {
    final token = request.uri.queryParameters['token'];

    if (token == null || token.isEmpty) {
      onLog?.call('Authentication failed: Missing token');
      return RequestAuthenticationResult.failure(
        reason: 'Missing token parameter',
        statusCode: 401,
      );
    }

    if (token != requiredToken) {
      onLog?.call('Authentication failed: Invalid token');
      return RequestAuthenticationResult.failure(
        reason: 'Invalid token',
        statusCode: 403,
      );
    }

    onLog?.call('Authentication successful for token: $token');
    return RequestAuthenticationResult.success(
      metadata: {'token': token},
    );
  }
}

/// Example implementation of ClientValidationDelegate
/// Validates that client has a username in details
class UsernameValidator implements ClientValidationDelegate {
  final void Function(String)? onLog;

  const UsernameValidator({this.onLog});

  @override
  Future<bool> validateClient(Client client, HttpRequest request) async {
    final username = client.details['username'];

    if (username == null || username.isEmpty) {
      onLog?.call('Client validation failed: Missing username');
      return false;
    }

    if (username.length < 3) {
      onLog?.call('Client validation failed: Username too short');
      return false;
    }

    onLog?.call('Client validated: $username');
    return true;
  }
}

/// Example implementation of MessageValidationDelegate
/// Validates that messages are not empty and not too long
class MessageValidator implements MessageValidationDelegate {
  final int maxLength;
  final void Function(String)? onLog;

  const MessageValidator({
    this.maxLength = 1000,
    this.onLog,
  });

  @override
  Future<bool> validateMessage(Client client, dynamic message) async {
    if (message == null) {
      onLog?.call('Message validation failed: null message');
      return false;
    }

    final messageStr = message.toString();

    if (messageStr.isEmpty) {
      onLog?.call('Message validation failed: empty message');
      return false;
    }

    if (messageStr.length > maxLength) {
      onLog?.call('Message validation failed: message too long (${messageStr.length} > $maxLength)');
      return false;
    }

    return true;
  }
}

// ===== APP =====

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local WebSocket Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Local WebSocket Example'), backgroundColor: Theme.of(context).colorScheme.inversePrimary),
      body: IndexedStack(index: _selectedIndex, children: [const ServerPage(), const ClientPage(), const ScannerPage()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dns), label: 'Server'),
          NavigationDestination(icon: Icon(Icons.phone_android), label: 'Client'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Scanner'),
        ],
      ),
    );
  }
}

// ===== SERVER PAGE =====
class ServerPage extends StatefulWidget {
  const ServerPage({super.key});

  @override
  State<ServerPage> createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Server? _server;
  final List<String> _logs = [];
  final _nameController = TextEditingController(text: 'My Local Server');
  final _portController = TextEditingController(text: '8080');
  final _hostController = TextEditingController(text: '127.0.0.1');
  final _tokenController = TextEditingController(text: 'secret123');
  List<Client> _connectedClients = [];
  StreamSubscription? _clientsSubscription;
  
  // Delegate toggles
  bool _useTokenAuth = false;
  bool _useConnectionLogging = true;
  bool _useUsernameValidation = false;
  bool _useMessageValidation = false;

  @override
  void dispose() {
    _clientsSubscription?.cancel();
    _server?.stop();
    _nameController.dispose();
    _portController.dispose();
    _hostController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, '${DateTime.now().toString().substring(11, 19)} - $message');
      if (_logs.length > 50) _logs.removeLast();
    });
  }

  Future<void> _startServer() async {
    try {
      final host = _hostController.text;
      final port = int.parse(_portController.text);

      _server = Server(
        echo: false, // Broadcast mode
        details: {
          'name': _nameController.text,
          'description': 'Flutter WebSocket Server Example',
          'version': '1.0.0',
          'platform': 'Flutter',
          'authEnabled': _useTokenAuth,
          'validationEnabled': _useUsernameValidation || _useMessageValidation,
        },
        requestAuthenticationDelegate: _useTokenAuth
            ? SimpleTokenAuthenticator(
                requiredToken: _tokenController.text,
                onLog: _addLog,
              )
            : null,
        clientConnectionDelegate: _useConnectionLogging
            ? LoggingConnectionDelegate(_addLog)
            : null,
        clientValidationDelegate: _useUsernameValidation
            ? UsernameValidator(onLog: _addLog)
            : null,
        messageValidationDelegate: _useMessageValidation
            ? MessageValidator(maxLength: 500, onLog: _addLog)
            : null,
      );

      await _server!.start(host, port: port);
      _addLog('Server started at ${_server!.address}');
      if (_useTokenAuth) {
        _addLog('Token authentication enabled (token: ${_tokenController.text})');
      }
      if (_useUsernameValidation) {
        _addLog('Username validation enabled');
      }
      if (_useMessageValidation) {
        _addLog('Message validation enabled (max 500 chars)');
      }

      // Listen for client connections
      _clientsSubscription = _server!.clientsStream.listen((clients) {
        setState(() {
          _connectedClients = clients.toList();
        });
        _addLog('Connected clients: ${clients.length}');
      });

      // Listen for messages from clients
      _server!.messageStream.listen((message) {
        _addLog('Message received: ${message.toString().substring(0, message.toString().length > 50 ? 50 : message.toString().length)}...');
      });

      setState(() {});
    } catch (e) {
      _addLog('Error starting server: $e');
    }
  }

  Future<void> _stopServer() async {
    try {
      await _clientsSubscription?.cancel();
      await _server?.stop();
      _addLog('Server stopped');
      setState(() {
        _server = null;
        _connectedClients = [];
      });
    } catch (e) {
      _addLog('Error stopping server: $e');
    }
  }

  void _broadcastMessage(String message) {
    if (_server != null) {
      _server!.send(message);
      _addLog('Broadcasted: $message');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isRunning = _server != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Server Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Server Name', border: OutlineInputBorder()),
                    enabled: !isRunning,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _hostController,
                          decoration: const InputDecoration(labelText: 'Host', border: OutlineInputBorder()),
                          enabled: !isRunning,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _portController,
                          decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          enabled: !isRunning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Security & Validation', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _useTokenAuth,
                    onChanged: isRunning ? null : (value) => setState(() => _useTokenAuth = value ?? false),
                    title: const Text('Token Authentication'),
                    subtitle: const Text('Require token in query params'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_useTokenAuth) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 8),
                      child: TextField(
                        controller: _tokenController,
                        decoration: const InputDecoration(
                          labelText: 'Required Token',
                          border: OutlineInputBorder(),
                          isDense: true,
                          helperText: 'Clients must include ?token=VALUE',
                        ),
                        enabled: !isRunning,
                      ),
                    ),
                  ],
                  CheckboxListTile(
                    value: _useConnectionLogging,
                    onChanged: isRunning ? null : (value) => setState(() => _useConnectionLogging = value ?? false),
                    title: const Text('Connection Logging'),
                    subtitle: const Text('Log client connect/disconnect events'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: _useUsernameValidation,
                    onChanged: isRunning ? null : (value) => setState(() => _useUsernameValidation = value ?? false),
                    title: const Text('Username Validation'),
                    subtitle: const Text('Require username (min 3 chars)'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: _useMessageValidation,
                    onChanged: isRunning ? null : (value) => setState(() => _useMessageValidation = value ?? false),
                    title: const Text('Message Validation'),
                    subtitle: const Text('Limit message length (500 chars)'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: isRunning ? null : _startServer,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Server'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: isRunning ? _stopServer : null,
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop Server'),
                        ),
                      ),
                    ],
                  ),
                  if (isRunning) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Running at ${_server!.address}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Connected Clients (${_connectedClients.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: _connectedClients.isEmpty
                        ? const SizedBox(height: 60, child: Center(child: Text('No clients connected')))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _connectedClients.length,
                            itemBuilder: (context, index) {
                              final client = _connectedClients[index];
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.person),
                                title: Text(client.uid),
                                subtitle: Text(client.details.isNotEmpty ? client.details.toString() : 'No details'),
                              );
                            },
                          ),
                  ),
                  if (isRunning) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(labelText: 'Broadcast Message', border: OutlineInputBorder(), isDense: true),
                            onSubmitted: (value) {
                              if (value.isNotEmpty) {
                                _broadcastMessage(value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Server Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: Card(
              child: _logs.isEmpty
                  ? const Center(child: Text('No logs yet'))
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Text(_logs[index], style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== CLIENT PAGE =====
class ClientPage extends StatefulWidget {
  const ClientPage({super.key});

  @override
  State<ClientPage> createState() => _ClientPageState();
}

class _ClientPageState extends State<ClientPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Client? _client;
  final List<String> _messages = [];
  final _urlController = TextEditingController(text: 'ws://127.0.0.1:8080/ws');
  final _usernameController = TextEditingController(text: 'User_${DateTime.now().millisecondsSinceEpoch % 1000}');
  final _tokenController = TextEditingController(text: 'secret123');
  final _messageController = TextEditingController();
  bool _isConnected = false;
  bool _useToken = false;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _messageSubscription;

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _messageSubscription?.cancel();
    _client?.disconnect();
    _urlController.dispose();
    _usernameController.dispose();
    _tokenController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _addMessage(String message) {
    setState(() {
      _messages.insert(0, '${DateTime.now().toString().substring(11, 19)} - $message');
      if (_messages.length > 50) _messages.removeLast();
    });
  }

  Future<void> _connect() async {
    try {
      // Build client details - include token if enabled
      final details = <String, String>{
        'username': _usernameController.text,
        'device': 'Flutter App',
        'platform': 'Mobile',
      };
      
      // Add token to details if enabled (this will be added as query parameter)
      if (_useToken) {
        details['token'] = _tokenController.text;
      }
      
      _client = Client(details: details);

      await _client!.connect(_urlController.text);
      _addMessage('Connected! Client ID: ${_client!.uid}');
      if (_useToken) {
        _addMessage('Using token: ${_tokenController.text}');
      }

      _connectionSubscription = _client!.connectionStream.listen((isConnected) {
        setState(() {
          _isConnected = isConnected;
        });
        _addMessage('Connection status: ${isConnected ? "Connected" : "Disconnected"}');
      });

      _messageSubscription = _client!.messageStream.listen((message) {
        _addMessage('Received: $message');
      });

      setState(() {
        _isConnected = true;
      });
    } catch (e) {
      _addMessage('Error connecting: $e');
    }
  }

  Future<void> _disconnect() async {
    try {
      await _connectionSubscription?.cancel();
      await _messageSubscription?.cancel();
      await _client?.disconnect();
      _addMessage('Disconnected');
      setState(() {
        _isConnected = false;
        _client = null;
      });
    } catch (e) {
      _addMessage('Error disconnecting: $e');
    }
  }

  void _sendMessage(String message) {
    if (_client != null && message.isNotEmpty) {
      _client!.send(message);
      _addMessage('Sent: $message');
      _messageController.clear();
    }
  }

  void _sendJsonMessage() {
    if (_client != null) {
      final jsonMessage = jsonEncode({
        'type': 'chat',
        'user': _usernameController.text,
        'message': _messageController.text,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _client!.send(jsonMessage);
      _addMessage('Sent JSON: ${jsonMessage.toString()}');
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Client Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                    enabled: !_isConnected,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'WebSocket URL',
                      border: OutlineInputBorder(),
                      helperText: 'Token will be added automatically if enabled',
                    ),
                    enabled: !_isConnected,
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _useToken,
                    onChanged: _isConnected ? null : (value) => setState(() => _useToken = value ?? false),
                    title: const Text('Use Token Authentication'),
                    subtitle: const Text('Add token to query parameters'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_useToken) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 12),
                      child: TextField(
                        controller: _tokenController,
                        decoration: const InputDecoration(
                          labelText: 'Token',
                          border: OutlineInputBorder(),
                          isDense: true,
                          helperText: 'Must match server token',
                        ),
                        enabled: !_isConnected,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isConnected ? null : _connect,
                          icon: const Icon(Icons.link),
                          label: const Text('Connect'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _isConnected ? _disconnect : null,
                          icon: const Icon(Icons.link_off),
                          label: const Text('Disconnect'),
                        ),
                      ),
                    ],
                  ),
                  if (_isConnected) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Connected as ${_client?.uid}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isConnected) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Send Message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder(), isDense: true),
                            onSubmitted: _sendMessage,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(onPressed: () => _sendMessage(_messageController.text), icon: const Icon(Icons.send), tooltip: 'Send Text'),
                        IconButton.filledTonal(onPressed: _sendJsonMessage, icon: const Icon(Icons.code), tooltip: 'Send as JSON'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          const Text('Messages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: Card(
              child: _messages.isEmpty
                  ? const Center(child: Text('No messages yet'))
                  : ListView.builder(
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Text(_messages[index], style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== SCANNER PAGE =====
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final List<DiscoveredServer> _discoveredServers = [];
  final _hostController = TextEditingController(text: 'localhost');
  final _portController = TextEditingController(text: '8080');
  bool _isScanning = false;
  StreamSubscription? _scanSubscription;

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _startScanning() async {
    setState(() {
      _isScanning = true;
      _discoveredServers.clear();
    });

    try {
      final host = _hostController.text;
      final port = int.parse(_portController.text);

      _scanSubscription = Scanner.scan(host, port: port).listen(
        (servers) {
          setState(() {
            _discoveredServers.clear();
            _discoveredServers.addAll(servers);
          });
        },
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan error: $error')));
          }
        },
      );
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _stopScanning() {
    _scanSubscription?.cancel();
    setState(() {
      _isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Scanner Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _hostController,
                          decoration: const InputDecoration(
                            labelText: 'Host / Subnet',
                            border: OutlineInputBorder(),
                            helperText: 'e.g., localhost or 192.168.1',
                          ),
                          enabled: !_isScanning,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _portController,
                          decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          enabled: !_isScanning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isScanning ? null : _startScanning,
                          icon: const Icon(Icons.search),
                          label: const Text('Start Scanning'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _isScanning ? _stopScanning : null,
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop Scanning'),
                        ),
                      ),
                    ],
                  ),
                  if (_isScanning) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text(
                      'Scanning for servers...',
                      style: TextStyle(fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Discovered Servers (${_discoveredServers.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 400,
            child: _discoveredServers.isEmpty
                ? Card(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            _isScanning ? 'Scanning for servers...' : 'No servers found',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _discoveredServers.length,
                    itemBuilder: (context, index) {
                      final server = _discoveredServers[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.dns, color: Colors.green),
                          title: Text(server.details['name']?.toString() ?? 'Unknown Server', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('URL: ${server.path}'),
                              if (server.details.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Details: ${server.details.entries.map((e) => '${e.key}: ${e.value}').join(', ')}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                              ],
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy),
                            tooltip: 'Copy URL',
                            onPressed: () {
                              // In a real app, you'd copy to clipboard
                              if (mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text('URL copied: ${server.path}'), duration: const Duration(seconds: 2)));
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
