import 'dart:async';
import 'dart:convert';
import 'dart:io' hide HttpResponse;

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

import 'client.dart';

final class Server {
  final bool _echo;
  final Map<String, dynamic> _details;
  final Set<Client> _clients = {};

  final _connectionBroadcast = StreamController<bool>.broadcast();
  final _clientsBroadcast = StreamController<Set<Client>>.broadcast();
  final _messageBroadcast = StreamController<dynamic>.broadcast();

  HttpServer? _server;

  Server({
    bool echo = false,
    Map<String, dynamic> details = const {},
  })  : _details = details,
        _echo = echo;

  Set<Client> get clients => Set.unmodifiable(_clients);
  Stream<Set<Client>> get clientsStream => _clientsBroadcast.stream;
  Stream<bool> get connectionStream => _connectionBroadcast.stream;
  Stream<dynamic> get messageStream => _messageBroadcast.stream;
  bool get isConnected => _server != null;

  Uri get address {
    if (_server == null) {
      throw StateError('Server is not running!');
    }
    return Uri.parse('http://${_server!.address.host}:${_server!.port}');
  }

  Future<void> start(
    String host, {
    int port = 8080,
  }) async {
    if (_server != null) {
      throw StateError('Server is already running on ${_server!.address.host}:${_server!.port}');
    }

    print('Starting server on $host:$port');

    final router = Router();
    router.get("/", _onInfo);
    router.mount("/ws", _onUpgrade);

    _server = await serve(router.call, host, port);

    print('Server started');

    _connectionBroadcast.add(true);
  }

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
        'Server': 'flutter-local-websocket/1.0.0',
      },
    );
  }

  Future<Response> _onUpgrade(Request request) async {
    final handler = webSocketHandler((channel, _) {
      final client = Client(
        channel: channel,
        details: request.url.queryParameters,
      );
      _clients.add(client);
      _clientsBroadcast.add(_clients);

      channel.stream.listen(
        (message) {
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
        onDone: () {
          _clients.remove(client);
          _clientsBroadcast.add(_clients);
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
