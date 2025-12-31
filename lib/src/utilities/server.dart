part of '../source.dart';

/// A WebSocket server that supports client management and authentication
class Server {
  final bool _echo;
  final Map<String, dynamic> _details;
  final RequestAuthenticationDelegate? _requestAuthenticationDelegate;
  final ClientValidationDelegate? _clientValidationDelegate;
  final ClientConnectionDelegate? _clientConnectionDelegate;
  final MessageValidationDelegate? _messageValidationDelegate;
  final Set<Client> _clients = {};
  final String _version = '1.0.0';

  final _connectionController = StreamController<bool>.broadcast();
  final _clientsController = StreamController<Set<Client>>.broadcast();
  final _messageController = StreamController<dynamic>.broadcast();

  HttpServer? _server;

  Server({
    bool echo = false,
    Map<String, dynamic> details = const {},
    RequestAuthenticationDelegate? requestAuthenticationDelegate,
    ClientValidationDelegate? clientValidationDelegate,
    ClientConnectionDelegate? clientConnectionDelegate,
    MessageValidationDelegate? messageValidationDelegate,
  })  : _details = Map.from(details),
        _echo = echo,
        _requestAuthenticationDelegate = requestAuthenticationDelegate,
        _clientValidationDelegate = clientValidationDelegate,
        _clientConnectionDelegate = clientConnectionDelegate,
        _messageValidationDelegate = messageValidationDelegate;

  /// The set of currently connected clients
  Set<Client> get clients => Set.unmodifiable(_clients);

  /// Stream of currently connected clients
  Stream<Set<Client>> get clientsStream => _clientsController.stream;

  /// Stream of connection status changes
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Stream of messages received by the server
  Stream<dynamic> get messageStream => _messageController.stream;

  /// Indicates whether the server is currently running
  bool get isConnected => _server != null;

  /// The address of the running server
  Uri get address {
    if (_server == null) {
      throw StateError('Server is not running!');
    }
    return Uri.parse('http://${_server!.address.host}:${_server!.port}');
  }

  /// Starts the server on the given [host] and [port]
  Future<void> start(
    String host, {
    int port = 8080,
  }) async {
    if (_server != null) {
      throw StateError(
        'Server is already running on ${_server!.address.host}:${_server!.port}',
      );
    }

    _server = await HttpServer.bind(host, port);

    _server!.listen((HttpRequest request) async {
      if (request.uri.path == '/ws') {
        await _handleWebSocketUpgrade(request);
      } else {
        await _handleHttpRequest(request);
      }
    });

    _connectionController.add(true);
  }

  /// Stops the server and disconnects all clients
  Future<void> stop() async {
    if (_server == null) {
      throw StateError('Server is not running!');
    }

    for (final client in Set.unmodifiable(_clients)) {
      await client.disconnect();
    }
    _clients.clear();

    await _server!.close();
    _server = null;

    _clientsController.add(Set.unmodifiable(_clients));
    _connectionController.add(false);
  }

  /// Handle HTTP info endpoint
  Future<void> _handleHttpRequest(HttpRequest request) async {
    final response = request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.json
      ..headers.add('Server', 'local-websocket/$_version')
      ..write(jsonEncode(_details));
    await response.close();
  }

  /// Handle WebSocket upgrade request
  Future<void> _handleWebSocketUpgrade(HttpRequest request) async {
    // Authenticate request if delegate is provided
    if (_requestAuthenticationDelegate != null) {
      final authResult = await _requestAuthenticationDelegate.authenticateRequest(request);

      if (!authResult.isSuccess) {
        final response = request.response
          ..statusCode = authResult.statusCode ?? 403
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'error': {
              'code': 'AUTHENTICATION_FAILED',
              'message': authResult.reason ?? 'Authentication failed',
              'statusCode': authResult.statusCode ?? 403,
            }
          }));
        await response.close();

        return;
      }
    }

    // Upgrade to WebSocket
    final socket = await WebSocketTransformer.upgrade(request);

    // Create client from query parameters
    final queryParams = Map<String, String>.from(
      request.uri.queryParameters.map((k, v) => MapEntry(k, v.toString())),
    );
    final client = Client.withSocket(socket: socket, details: queryParams);

    // Validate client if delegate is provided
    if (_clientValidationDelegate != null) {
      final isValid = await _clientValidationDelegate.validateClient(client, request);
      if (!isValid) {
        await socket.close(3000, 'Client validation failed');
        return;
      }
    }

    // Add client to set
    _clients.add(client);
    _clientsController.add(Set.unmodifiable(_clients));

    // Notify connection delegate
    await _clientConnectionDelegate?.onClientConnected(client);

    // Listen for messages from this client
    socket.listen(
      (message) async {
        // Validate message if delegate is provided
        if (_messageValidationDelegate != null) {
          final isValid = await _messageValidationDelegate.validateMessage(client, message);
          if (!isValid) {
            return;
          }
        }

        // Broadcast or echo message
        for (final otherClient in _clients) {
          if (_echo) {
            otherClient.send(message);
          } else {
            if (otherClient.uid != client.uid) {
              otherClient.send(message);
            }
          }
        }

        _messageController.add(message);
      },
      onDone: () async {
        _clients.remove(client);
        _clientsController.add(Set.unmodifiable(_clients));
        await _clientConnectionDelegate?.onClientDisconnected(client);
      },
      onError: (error) async {
        _clients.remove(client);
        _clientsController.add(Set.unmodifiable(_clients));
        await _clientConnectionDelegate?.onClientDisconnected(client);
      },
    );
  }

  /// Send a message to all connected clients
  void send(dynamic message) {
    if (_server == null) {
      throw StateError('Server is not running!');
    }

    for (final client in _clients) {
      client.send(message);
    }

    if (_echo) {
      _messageController.add(message);
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    if (_server != null) {
      await stop();
    }
    await _connectionController.close();
    await _clientsController.close();
    await _messageController.close();
  }
}
