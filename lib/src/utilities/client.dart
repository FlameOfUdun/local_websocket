part of '../source.dart';

/// Represents a WebSocket client that can connect to a server, send and receive messages.
final class Client {
  /// Unique identifier for the client instance.
  late final uid = const Uuid().v4();

  final Map<String, String> _details;
  final _messageBroadcast = StreamController<dynamic>.broadcast();
  final _connectionBroadcast = StreamController<bool>.broadcast();

  WebSocketChannel? _channel;

  /// Creates a [Client] with optional [details] about the client.
  Client({
    Map<String, String> details = const {},
  }) : _details = details;

  /// Creates a [Client] with an established WebSocket [channel] and optional [details].
  Client.withChannel({
    required WebSocketChannel channel,
    Map<String, String> details = const {},
  })  : _details = details,
        _channel = channel;

  /// Additional details about the client.
  Map<String, String> get details => Map.unmodifiable(_details);

  /// Indicates whether the client is currently connected.
  bool get isConnected => _channel != null;

  /// Stream of incoming messages from the server.
  Stream<dynamic> get messageStream => _messageBroadcast.stream;

  /// Stream of connection status changes.
  Stream<bool> get connectionStream => _connectionBroadcast.stream;

  /// Connect to a WebSocket server at the given [path].
  Future<void> connect(String path) async {
    if (_channel != null) {
      throw StateError('Client is already connected!');
    }

    try {
      final uri = Uri.parse(path).replace(queryParameters: _details);
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (message) {
          _messageBroadcast.add(message);
        },
        onDone: () {
          _channel = null;
          _connectionBroadcast.add(false);
        },
        onError: (error) {
          _channel = null;
          _connectionBroadcast.add(false);
        },
        cancelOnError: true,
      );

      await _channel!.ready;
      _connectionBroadcast.add(true);
    } catch (e) {
      _channel = null;
      _connectionBroadcast.add(false);
      rethrow;
    }
  }

  /// Send a [message] to the connected WebSocket server.
  void send(dynamic message) {
    if (_channel == null) {
      throw StateError('Client is not connected!');
    }
    _channel!.sink.add(message);
  }

  /// Disconnect from the WebSocket server.
  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
    _connectionBroadcast.add(false);
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
