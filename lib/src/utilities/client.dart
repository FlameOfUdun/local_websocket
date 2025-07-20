import 'dart:async';

import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final class Client {
  late final uid = const Uuid().v4();

  WebSocketChannel? _channel;
  final Map<String, String> _details;
  final _messageBroadcast = StreamController<dynamic>.broadcast();
  final _connectionBroadcast = StreamController<bool>.broadcast();

  Client({
    WebSocketChannel? channel,
    Map<String, String> details = const {},
  })  : _details = details,
        _channel = channel;

  Map<String, String> get details => Map.unmodifiable(_details);
  bool get isConnected => _channel != null;
  Stream<dynamic> get messageStream => _messageBroadcast.stream;
  Stream<bool> get connectionStream => _connectionBroadcast.stream;

  Future<void> connect(String path) async {
    if (_channel != null) {
      throw StateError('Client is already connected!');
    }

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
      cancelOnError: true,
    );

    _connectionBroadcast.add(true);
  }
  
  void send(dynamic message) {
    if (_channel == null) {
      throw StateError('Client is not connected!');
    }
    _channel!.sink.add(message);
  }

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
