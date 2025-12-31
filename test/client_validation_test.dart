import 'dart:async';

import 'package:shelf/shelf.dart' hide Server;
import 'package:test/test.dart';
import 'package:local_websocket/local_websocket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  group('ClientValidationDelegate', () {
    late Server server;
    const testPort = 8082;

    tearDown(() async {
      if (server.isConnected) {
        await server.stop();
      }
    });

    test('should accept client when validation returns true', () async {
      server = Server(
        clientValidationDelegate: _AlwaysAllowValidator(),
      );
      await server.start('127.0.0.1', port: testPort);

      final client = Client();
      await client.connect('ws://127.0.0.1:$testPort/ws');

      await Future.delayed(Duration(milliseconds: 500));
      expect(client.isConnected, isTrue);
      expect(server.clients.length, equals(1));

      await client.disconnect();
      await server.stop();
    });

    test('should reject client when validation returns false', () async {
      server = Server(
        clientValidationDelegate: _AlwaysDenyValidator(),
      );
      await server.start('127.0.0.1', port: testPort);

      final client = Client();

      try {
        await client.connect('ws://127.0.0.1:$testPort/ws');

        // Wait for disconnection
        await Future.delayed(Duration(milliseconds: 500));
      } on WebSocketChannelException catch (_) {
        // Connection may fail immediately
      } catch (e) {
        // Any exception is acceptable
      }

      // Client should not be in server's client list
      expect(server.clients.length, equals(0));

      await server.stop();
    });

    test('should validate based on client details', () async {
      server = Server(
        clientValidationDelegate: _UsernameValidator(),
      );
      await server.start('127.0.0.1', port: testPort);

      // Client with valid username
      final validClient = Client(details: {'username': 'Alice'});
      await validClient.connect('ws://127.0.0.1:$testPort/ws');

      await Future.delayed(Duration(milliseconds: 500));
      expect(validClient.isConnected, isTrue);
      expect(server.clients.length, equals(1));

      await validClient.disconnect();
      await Future.delayed(Duration(milliseconds: 300));

      // Client with invalid username (too short)
      final invalidClient = Client(details: {'username': 'Al'});

      try {
        await invalidClient.connect('ws://127.0.0.1:$testPort/ws');
        await Future.delayed(Duration(milliseconds: 500));
      } on WebSocketChannelException catch (_) {
        // Expected
      } catch (e) {
        // Any exception is acceptable
      }

      // Invalid client should not be added
      expect(server.clients.length, equals(0));

      await server.stop();
    });

    test('should enforce maximum client limit', () async {
      server = Server(
        clientValidationDelegate: _MaxClientsValidator(maxClients: 2),
      );
      await server.start('127.0.0.1', port: testPort);

      // Connect first client
      final client1 = Client(details: {'name': 'Client1'});
      await client1.connect('ws://127.0.0.1:$testPort/ws');
      await Future.delayed(Duration(milliseconds: 300));
      expect(server.clients.length, equals(1));

      // Connect second client
      final client2 = Client(details: {'name': 'Client2'});
      await client2.connect('ws://127.0.0.1:$testPort/ws');
      await Future.delayed(Duration(milliseconds: 300));
      expect(server.clients.length, equals(2));

      // Try to connect third client (should be rejected)
      final client3 = Client(details: {'name': 'Client3'});

      try {
        await client3.connect('ws://127.0.0.1:$testPort/ws');
        await Future.delayed(Duration(milliseconds: 500));
      } on WebSocketChannelException catch (_) {
        // Expected
      } catch (e) {
        // Any exception is acceptable
      }

      // Should still only have 2 clients
      expect(server.clients.length, equals(2));

      await client1.disconnect();
      await client2.disconnect();
      await server.stop();
    });

    test('should validate based on request context', () async {
      server = Server(
        clientValidationDelegate: _QueryParameterValidator(),
      );
      await server.start('127.0.0.1', port: testPort);

      // Client with required parameter
      final validClient = Client(details: {'role': 'admin'});
      await validClient.connect('ws://127.0.0.1:$testPort/ws');

      await Future.delayed(Duration(milliseconds: 500));
      expect(validClient.isConnected, isTrue);
      expect(server.clients.length, equals(1));

      await validClient.disconnect();
      await server.stop();
    });
  });
}

// Test validators

class _AlwaysAllowValidator implements ClientValidationDelegate {
  @override
  Future<bool> validateClient(Client client, Request request) async {
    return true;
  }
}

class _AlwaysDenyValidator implements ClientValidationDelegate {
  @override
  Future<bool> validateClient(Client client, Request request) async {
    return false;
  }
}

class _UsernameValidator implements ClientValidationDelegate {
  @override
  Future<bool> validateClient(Client client, Request request) async {
    final username = client.details['username'];

    if (username == null || username.isEmpty) {
      return false;
    }

    if (username.length < 3) {
      return false;
    }

    return true;
  }
}

class _MaxClientsValidator implements ClientValidationDelegate {
  final int maxClients;
  final Set<Client> _currentClients = {};

  _MaxClientsValidator({required this.maxClients});

  @override
  Future<bool> validateClient(Client client, Request request) async {
    // Note: In real implementation, you'd need access to server.clients
    // This is a simplified version for testing
    if (_currentClients.length >= maxClients) {
      return false;
    }
    _currentClients.add(client);
    return true;
  }
}

class _QueryParameterValidator implements ClientValidationDelegate {
  @override
  Future<bool> validateClient(Client client, Request request) async {
    final role = request.url.queryParameters['role'];
    return role != null && role.isNotEmpty;
  }
}
