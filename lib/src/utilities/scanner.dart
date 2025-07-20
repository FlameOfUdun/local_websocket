import 'package:dio/dio.dart';

import '../models/discovered_server.dart';

final class Scanner {
  Scanner._();

  static Future<List<DiscoveredServer>> scan(String host, {
    int port = 8080,
  }) async {
    final subnet = _subnet(host);
    final tasks = <Future<DiscoveredServer?>>[];
    for (var ip = 0; ip <= 255; ip++) {
      tasks.add(_check(subnet, ip, port));
    }

    final result = await Future.wait(tasks);
    return result.nonNulls.toList();
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

  static Future<DiscoveredServer?> _check(String subnet, int ip, int port) async {
    final client = Dio(BaseOptions(
      receiveTimeout: const Duration(seconds: 1),
      connectTimeout: const Duration(seconds: 1),
      sendTimeout: const Duration(seconds: 1),
      validateStatus: (status) => status == 200,
    ));
    try {
      final response = await client.get('http://$subnet.$ip:$port');
      final server = response.headers['Server']?.first;
      if (server == null || !server.contains('flutter-local-websocket')) return null;
      final data = response.data;
      return DiscoveredServer(
        path: 'ws://$subnet.$ip:$port/ws',
        details: data,
      );
    } catch (e) {
      return null;
    } finally {
      client.close();
    }
  }
}
