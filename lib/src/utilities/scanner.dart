part of '../source.dart';

/// A utility class for scanning a local network for available WebSocket servers.
final class Scanner {
  /// Scans the local network for WebSocket servers of the specified [type] and [port].
  /// By default, it scans for servers of type 'local-websocket' on port 8080.
  /// The scan runs at the specified [interval].
  static Stream<List<DiscoveredServer>> scan(
    String host, {
    String type = 'local-websocket',
    int port = 8080,
    Duration interval = const Duration(seconds: 3),
  }) async* {
    while (true) {
      final subnet = _subnet(host);
      final tasks = List<Future<DiscoveredServer?>>.generate(
        256,
        (ip) {
          return _check(
            subnet: subnet,
            ip: ip,
            port: port,
            type: type,
          );
        },
      );
      final result = await Future.wait(tasks);
      yield result.nonNulls.toList();

      await Future.delayed(interval);
    }
  }

  static String _subnet(String host) {
    if (host == 'localhost' || host == '127.0.0.1') {
      return '127.0.0';
    }

    if (host.contains('.')) {
      final parts = host.split('.');
      if (parts.length < 3) {
        throw ArgumentError('Invalid host format: $host');
      }
      return '${parts[0]}.${parts[1]}.${parts[2]}';
    }

    throw ArgumentError('Invalid host format: $host');
  }

  static Future<DiscoveredServer?> _check({
    required String subnet,
    required int ip,
    required int port,
    required String type,
  }) async {
    final client = dio.Dio(dio.BaseOptions(
      receiveTimeout: const Duration(seconds: 1),
      connectTimeout: const Duration(seconds: 1),
      sendTimeout: const Duration(seconds: 1),
      validateStatus: (status) => status == 200,
    ));

    try {
      final response = await client.get('http://$subnet.$ip:$port');
      final server = response.headers['Server']?.first;
      if (server == null || !server.contains(type)) {
        return null;
      }
      return DiscoveredServer(
        path: 'ws://$subnet.$ip:$port/ws',
        details: response.data ?? <String, dynamic>{},
      );
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }
}
