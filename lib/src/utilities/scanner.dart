part of '../source.dart';

/// Scanner for discovering WebSocket servers on the network
class Scanner {
  /// Scan for servers on the given [host] and [port]
  ///
  /// The [host] can be:
  /// - A specific host: 'localhost', '192.168.1.100'
  /// - A subnet: '192.168.1' (will scan .1 to .254)
  ///
  /// Returns a Stream that emits lists of discovered servers every [interval]
  static Stream<List<DiscoveredServer>> scan(
    String host, {
    int port = 8080,
    Duration interval = const Duration(seconds: 3),
    Duration timeout = const Duration(seconds: 1),
  }) async* {
    while (true) {
      final servers = await _scanOnce(host, port: port, timeout: timeout);
      yield servers;
      await Future.delayed(interval);
    }
  }

  /// Perform a single scan
  static Future<List<DiscoveredServer>> _scanOnce(
    String host, {
    required int port,
    required Duration timeout,
  }) async {
    final servers = <DiscoveredServer>[];

    // Check if host is a subnet (e.g., '192.168.1')
    if (_isSubnet(host)) {
      // Scan all addresses in subnet
      final futures = <Future<DiscoveredServer?>>[];
      for (int i = 1; i < 255; i++) {
        final address = '$host.$i';
        futures.add(_checkServer(address, port, timeout));
      }

      final results = await Future.wait(futures);
      servers.addAll(results.whereType<DiscoveredServer>());
    } else {
      // Single host scan
      final result = await _checkServer(host, port, timeout);
      if (result != null) {
        servers.add(result);
      }
    }

    return servers;
  }

  /// Check if a server exists at the given address
  static Future<DiscoveredServer?> _checkServer(
    String host,
    int port,
    Duration timeout,
  ) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = timeout;

      final request = await client
          .getUrl(Uri.parse('http://$host:$port/'))
          .timeout(timeout);

      final response = await request.close().timeout(timeout);

      if (response.statusCode == 200) {
        // Check if it's a local-websocket server
        final serverHeader = response.headers.value('server');
        if (serverHeader != null && serverHeader.contains('local-websocket')) {
          // Read response body
          final body = await response.transform(utf8.decoder).join();
          final details = jsonDecode(body) as Map<String, dynamic>;

          client.close();
          return DiscoveredServer(
            path: 'ws://$host:$port/ws',
            details: details,
          );
        }
      }

      client.close();
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if the host string represents a subnet
  static bool _isSubnet(String host) {
    // A subnet is an incomplete IP address (e.g., '192.168.1')
    final parts = host.split('.');
    return parts.length == 3 && parts.every(_isValidOctet);
  }

  /// Check if a string is a valid IP octet
  static bool _isValidOctet(String part) {
    final num = int.tryParse(part);
    return num != null && num >= 0 && num <= 255;
  }
}
