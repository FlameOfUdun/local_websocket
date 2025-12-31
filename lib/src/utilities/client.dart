part of '../source.dart';


/// Represents a WebSocket client that can connect to a server
class Client {
  /// Unique identifier for the client instance
  late final String uid = _generateUid();

  /// Additional details about the client
  final Map<String, String> _details;

  /// WebSocket connection
  WebSocket? _socket;

  /// Stream controller for incoming messages
  final _messageController = StreamController<dynamic>.broadcast();

  /// Stream controller for connection status changes
  final _connectionController = StreamController<bool>.broadcast();

  /// Creates a [Client] with optional [details] about the client
  Client({
    Map<String, String> details = const {},
  }) : _details = Map.unmodifiable(details);

  /// Creates a [Client] with an established WebSocket [socket] and optional [details]
  Client.withSocket({
    required WebSocket socket,
    Map<String, String> details = const {},
  })  : _details = Map.unmodifiable(details),
        _socket = socket;

  /// Additional details about the client
  Map<String, String> get details => _details;

  /// Indicates whether the client is currently connected
  bool get isConnected => _socket != null;

  /// Stream of incoming messages from the server
  Stream<dynamic> get messageStream => _messageController.stream;

  /// Stream of connection status changes
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Connect to a WebSocket server at the given [url]
  Future<void> connect(String url) async {
    if (_socket != null) {
      throw StateError('Client is already connected!');
    }

    try {
      // Parse URL and add details as query parameters
      final uri = Uri.parse(url);
      final newQueryParams = Map<String, String>.from(uri.queryParameters);
      newQueryParams.addAll(_details);
      
      final finalUri = uri.replace(queryParameters: newQueryParams);

      // Connect to WebSocket
      _socket = await WebSocket.connect(finalUri.toString());
      _setupSocketListeners();
      _connectionController.add(true);
    } on WebSocketException catch (e) {
      _socket = null;
      _connectionController.add(false);

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
      _connectionController.add(false);
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
        _connectionController.add(false);
      },
      onError: (error) {
        _socket = null;
        _connectionController.add(false);
      },
      cancelOnError: true,
    );
  }

  /// Send a [message] to the connected WebSocket server
  void send(dynamic message) {
    if (_socket == null) {
      throw StateError('Client is not connected!');
    }
    _socket!.add(message);
  }

  /// Disconnect from the WebSocket server
  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
    _connectionController.add(false);
  }

  /// Dispose resources
  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
    await _connectionController.close();
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
