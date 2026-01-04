part of '../source.dart';

/// Represents a WebSocket client that can connect to a server
class Client {
  late final String uid = _generateUid();
  final Map<String, String> _details;
  WebSocket? _socket;
  final _messageController = StreamController<dynamic>.broadcast();
  final _statusController =
      StreamController<ClientConnectionStatus>.broadcast();

  ClientReconectionDelegate? _clientReconnectionDelegate;
  String? _lastConnectionUrl;
  int _reconnectAttempts = 0;
  DateTime? _lastConnectedTime;
  bool _isReconnecting = false;
  bool _shouldStopReconnecting = false;
  ClientConnectionStatus _currentStatus = ClientConnectionStatus.disconnected;

  /// Creates a [Client] with optional [details] about the client
  Client({
    Map<String, String> details = const {},
    ClientReconectionDelegate? clientReconnectionDelegate,
  })  : _details = Map.unmodifiable(details),
        _clientReconnectionDelegate = clientReconnectionDelegate;

  /// Creates a [Client] with an established WebSocket [socket] and optional [details]
  Client.connected({
    required WebSocket socket,
    Map<String, String> details = const {},
    ClientReconectionDelegate? clientReconnectionDelegate,
  })  : _details = Map.unmodifiable(details),
        _socket = socket,
        _currentStatus = ClientConnectionStatus.connected,
        _clientReconnectionDelegate = clientReconnectionDelegate;

  /// Additional details about the client
  Map<String, String> get details => Map<String, String>.unmodifiable(_details);

  /// Indicates whether the client is currently connected
  bool get isConnected => _currentStatus == ClientConnectionStatus.connected;

  /// Stream of incoming messages from the server
  Stream<dynamic> get messageStream => _messageController.stream;

  /// Delegate for handling reconnection logic
  set clientReconnectionDelegate(ClientReconectionDelegate? delegate) {
    _clientReconnectionDelegate = delegate;
  }

  /// Stream of connection status changes
  Stream<ClientConnectionStatus> get connectionStream =>
      _statusController.stream;

  /// Current connection status of the client
  ClientConnectionStatus get connectionStatus => _currentStatus;

  // Helper method to update status
  void _updateStatus(ClientConnectionStatus newStatus) {
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _statusController.add(newStatus);
    }
  }

  /// Connect to a WebSocket server at the given [url]
  Future<void> connect(String url) async {
    if (_socket != null) {
      throw StateError('Client is already connected!');
    }

    _lastConnectionUrl = url;
    _shouldStopReconnecting = false;
    _reconnectAttempts = 0;
    _updateStatus(ClientConnectionStatus.connecting);

    try {
      final uri = Uri.parse(url);
      final newQueryParams = Map<String, String>.from(uri.queryParameters);
      newQueryParams.addAll(_details);
      final finalUri = uri.replace(queryParameters: newQueryParams);

      _socket = await WebSocket.connect(finalUri.toString());
      _setupSocketListeners();
      _lastConnectedTime = DateTime.now();
      _updateStatus(ClientConnectionStatus.connected);
    } on WebSocketException catch (e) {
      _socket = null;
      _updateStatus(ClientConnectionStatus.disconnected);

      // Parse error to provide better messages
      final errorMessage = e.message;
      if (errorMessage.contains('401') ||
          errorMessage.toLowerCase().contains('unauthorized')) {
        throw WebSocketError.authenticationFailed(
          message: 'Authentication required',
          statusCode: 401,
        );
      } else if (errorMessage.contains('403') ||
          errorMessage.toLowerCase().contains('forbidden')) {
        throw WebSocketError.authenticationFailed(
          message: 'Authentication failed: Invalid credentials',
          statusCode: 403,
        );
      } else {
        throw WebSocketError.connectionFailed(
          message: 'Connection failed: $errorMessage',
          originalError: e,
        );
      }
    } catch (e) {
      _socket = null;
      _updateStatus(ClientConnectionStatus.disconnected);
      throw WebSocketError.connectionFailed(
        message: 'Connection failed',
        originalError: e,
      );
    }
  }

  /// Set up listeners for the WebSocket
  void _setupSocketListeners() {
    _socket?.listen(
      (message) {
        _messageController.add(message);
      },
      onDone: () {
        _socket = null;

        // Trigger auto-reconnect if delegate is provided
        if (_clientReconnectionDelegate != null && !_shouldStopReconnecting) {
          _updateStatus(ClientConnectionStatus.connecting);
          _attemptReconnect();
        } else {
          _updateStatus(ClientConnectionStatus.disconnected);
        }
      },
      onError: (error) {
        _socket = null;

        // Trigger auto-reconnect if delegate is provided
        if (_clientReconnectionDelegate != null && !_shouldStopReconnecting) {
          _updateStatus(ClientConnectionStatus.connecting);
          _attemptReconnect();
        } else {
          _updateStatus(ClientConnectionStatus.disconnected);
        }
      },
      cancelOnError: true,
    );
  }

  Future<void> _attemptReconnect() async {
    if (_isReconnecting ||
        _lastConnectionUrl == null ||
        _clientReconnectionDelegate == null) {
      return;
    }

    _isReconnecting = true;
    final timeSinceLastConnect = _lastConnectedTime != null
        ? DateTime.now().difference(_lastConnectedTime!)
        : Duration.zero;

    final shouldReconnect = await _clientReconnectionDelegate!
        .shouldReconnect(_reconnectAttempts, timeSinceLastConnect);

    if (!shouldReconnect) {
      _isReconnecting = false;
      _updateStatus(ClientConnectionStatus.disconnected);
      _clientReconnectionDelegate!.onReconnectFailed(_reconnectAttempts);
      return;
    }

    final delay = await _clientReconnectionDelegate!
        .getReconnectDelay(_reconnectAttempts);
    await Future.delayed(delay);

    if (_shouldStopReconnecting) {
      _isReconnecting = false;
      _updateStatus(ClientConnectionStatus.disconnected);
      return;
    }

    try {
      _reconnectAttempts++;

      final uri = Uri.parse(_lastConnectionUrl!);
      final newQueryParams = Map<String, String>.from(uri.queryParameters);
      newQueryParams.addAll(_details);
      final finalUri = uri.replace(queryParameters: newQueryParams);

      _socket = await WebSocket.connect(finalUri.toString());
      _setupSocketListeners();
      _lastConnectedTime = DateTime.now();
      _updateStatus(ClientConnectionStatus.connected);

      _reconnectAttempts = 0;
      _isReconnecting = false;
      _clientReconnectionDelegate!.onReconnected(_reconnectAttempts);
    } catch (e) {
      _isReconnecting = false;
      await _attemptReconnect();
    }
  }

  /// Send a [message] to the connected WebSocket server
  ///
  /// Throws a [StateError] if the client is not connected
  ///
  /// The [message] must be either a [String], [List<int>], or [Uint8List]
  void send(dynamic message) {
    if (_socket == null) {
      throw StateError('Client is not connected!');
    }

    if (message is! String && message is! List<int> && message is! Uint8List) {
      throw ArgumentError.value(message, 'message',
          'Message must be a String or List<int> or Uint8List');
    }

    _socket!.add(message);
  }

  /// Disconnect from the WebSocket server
  Future<void> disconnect() async {
    _shouldStopReconnecting = true;
    _isReconnecting = false;

    await _socket?.close();
    _socket = null;
    _updateStatus(ClientConnectionStatus.disconnected);
  }

  /// Attempt to reconnect using the reconnection delegate
  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
    await _statusController.close(); // Close status stream
  }

  /// Generate a unique ID for the client
  static String _generateUid() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = timestamp.hashCode;
    return '$timestamp-$random';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Client) return false;
    return uid == other.uid;
  }

  @override
  int get hashCode => uid.hashCode;
}
