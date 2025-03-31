import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

final class WebsocketClient {
  final String address;

  WebSocketChannel? _channel;
  final _messageBroadcast = StreamController<dynamic>.broadcast();
  final _connectedBroadcast = StreamController<bool>.broadcast();

  WebsocketClient(this.address);

  Future<void> initialize() async {
    if (_channel != null) {
      throw StateError('Client is already connected!');
    }

    final uri = Uri.parse(address);
    _channel = WebSocketChannel.connect(uri);

    _connectedBroadcast.add(true);

    _channel!.stream.listen(
      (message) {
        _messageBroadcast.add(message);
      },
      onDone: () {
        _channel = null;
        _connectedBroadcast.add(false);
      },
      cancelOnError: true,
    );
  }

  bool get isConnected => _channel != null;

  StreamSubscription<dynamic> onMessage(void Function(dynamic event) callback) {
    if (_channel == null) {
      throw StateError('Client is not connected!');
    }
    return _messageBroadcast.stream.listen(callback);
  }

  StreamSubscription<bool> onConnection(void Function(bool event) callback) {
    if (_channel == null) {
      throw StateError('Client is not connected!');
    }
    return _connectedBroadcast.stream.listen(callback);
  }

  void send(dynamic message) {
    if (_channel == null) {
      throw StateError('Client is not connected!');
    }
    _channel!.sink.add(message);
  }

  void dispose() {
    _channel?.sink.close();
    _channel = null;
  }
}
