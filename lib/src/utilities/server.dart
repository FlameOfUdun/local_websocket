part of '../source.dart';

/// A WebSocket server that supports client management and authentication.
final class Server {
  final bool _echo;
  final Map<String, dynamic> _details;
  final RequestAuthenticationDelegate? _requestAuthenticatorDelegate;
  final ClientValidationDelegate? _clientValidationDelegate;
  final ClientConnectionDelegate? _clientConnectionDelegate;
  final MessageValidationDelegate? _messageValidationDelegate;
  final Set<Client> _clients = {};
  final String _version = '1.0.0';

  final _connectionBroadcast = StreamController<bool>.broadcast();
  final _clientsBroadcast = StreamController<Set<Client>>.broadcast();
  final _messageBroadcast = StreamController<dynamic>.broadcast();

  HttpServer? _server;

  Server({
    bool echo = false,
    Map<String, dynamic> details = const {},
    RequestAuthenticationDelegate? requestAuthenticationDelegate,
    ClientValidationDelegate? clientValidationDelegate,
    ClientConnectionDelegate? clientConnectionDelegate,
    MessageValidationDelegate? messageValidationDelegate,
  })  : _details = details,
        _echo = echo,
        _requestAuthenticatorDelegate = requestAuthenticationDelegate,
        _clientValidationDelegate = clientValidationDelegate,
        _clientConnectionDelegate = clientConnectionDelegate,
        _messageValidationDelegate = messageValidationDelegate;

  /// The set of currently connected clients.
  Set<Client> get clients => Set.unmodifiable(_clients);

  /// Stream of currently connected clients.
  Stream<Set<Client>> get clientsStream => _clientsBroadcast.stream;

  /// Stream of connection status changes.
  Stream<bool> get connectionStream => _connectionBroadcast.stream;

  /// Stream of messages received by the server.
  Stream<dynamic> get messageStream => _messageBroadcast.stream;

  /// Indicates whether the server is currently running.
  bool get isConnected => _server != null;

  /// The address of the running server.
  Uri get address {
    if (_server == null) {
      throw StateError('Server is not running!');
    }
    return Uri.parse('http://${_server!.address.host}:${_server!.port}');
  }

  /// Starts the server on the given [host] and [port].
  Future<void> start(
    String host, {
    int port = 8080,
  }) async {
    if (_server != null) {
      throw StateError(
          'Server is already running on ${_server!.address.host}:${_server!.port}');
    }

    print('Starting server on $host:$port');

    final router = Router();
    router.get("/", _onInfo);
    router.mount("/ws", _onUpgrade);

    _server = await serve(router.call, host, port);

    print('Server started');

    _connectionBroadcast.add(true);
  }

  /// Stops the server and disconnects all clients.
  Future<void> stop() async {
    if (_server == null) {
      throw StateError('Server is not running!');
    }

    print('Stopping server on ${_server!.address.host}:${_server!.port}');

    for (final client in Set.unmodifiable(_clients)) {
      client.disconnect().ignore();
    }
    _clients.clear();

    await _server!.close();
    _server = null;

    print('Server stopped');

    _clientsBroadcast.add(Set.unmodifiable(_clients));
    _connectionBroadcast.add(false);
  }

  Future<Response> _onInfo(Request request) async {
    return Response.ok(
      jsonEncode(_details),
      headers: {
        'Content-Type': 'application/json',
        'Server': 'local-websocket/$_version',
      },
    );
  }

  Future<Response> _onUpgrade(Request request) async {
    final requestAuthenticationResult =
        await _requestAuthenticatorDelegate?.authenticateRequest(request);
    if (requestAuthenticationResult != null &&
        !requestAuthenticationResult.isSuccess) {
      return Response(
        requestAuthenticationResult.statusCode ?? 403,
        body: requestAuthenticationResult.reason ?? 'Authentication failed',
      );
    }

    final handler = webSocketHandler((channel, _) async {
      final client = Client.withChannel(
        channel: channel,
        details: request.url.queryParameters,
      );

      final clientValidationResult =
          await _clientValidationDelegate?.validateClient(client, request);
      if (clientValidationResult != null && !clientValidationResult) {
        await channel.sink.close(3000, 'Client validation failed');
        return;
      }

      _clients.add(client);
      _clientsBroadcast.add(Set.unmodifiable(_clients));

      Future(() async {
        await _clientConnectionDelegate?.onClientConnected(client);
      }).ignore();

      channel.stream.listen(
        (message) async {
          try {
            final messageValidationResult = await _messageValidationDelegate
                ?.validateMessage(client, message);
            if (messageValidationResult != null && !messageValidationResult) {
              return;
            }
          } catch (e) {
            return;
          }

          for (final item in _clients) {
            if (_echo) {
              item.send(message);
            } else {
              if (item.uid != client.uid) {
                item.send(message);
              }
            }
          }

          _messageBroadcast.add(message);
        },
        onDone: () async {
          _clients.remove(client);
          _clientsBroadcast.add(Set.unmodifiable(_clients));

          Future(() async {
            await _clientConnectionDelegate?.onClientDisconnected(client);
          }).ignore();
        },
      );
    });

    return handler.call(request);
  }

  void send(dynamic message) {
    if (_server == null) {
      throw StateError('Server is not running!');
    }

    for (final client in _clients) {
      client.send(message);
    }

    if (_echo) {
      _messageBroadcast.add(message);
    }
  }
}
