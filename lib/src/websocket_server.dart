import 'dart:async';
import 'dart:io';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final class WebSocketServer {
  final int _port;
  final String _host;
  final Duration? _ping;
  final Set<WebSocketChannel> _clients = {};

  HttpServer? _server;

  WebSocketServer({required int port, required String host, Duration? ping = const Duration(seconds: 1)}) : _ping = ping, _host = host, _port = port;

  String get address => 'ws://${_server!.address.address}:${_server!.port}';

  Future<void> initialize() async {
    if (_server != null) {
      throw StateError('Server is already running!');
    }

    final handler = webSocketHandler(_onConnect, pingInterval: _ping);
    _server = await serve(handler, _host, _port);
  }

  void dispose() {
    _server?.close();
    _server = null;
  }

  void _onConnect(WebSocketChannel channel, String? _) {
    _clients.add(channel);

    channel.stream.listen(
      (message) {
        print('Received message: $message');
        for (final client in _clients) {
          if (client != channel) {
            client.sink.add(message);
          }
        }
      },
      onDone: () {
        _clients.remove(channel);
      },
    );
  }
}
