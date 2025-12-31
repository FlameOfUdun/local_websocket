import 'dart:async';

import 'package:test/test.dart';
import 'package:local_websocket/local_websocket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  group('Authentication', () {
    late Server server;
    const testPort =
        8081; // Use different port to avoid conflicts with server_test.dart

    tearDown(() async {
      if (server.isConnected) {
        await server.stop();
      }
    });

    test('should accept connections with no authenticator', () async {
      server = Server();
      await server.start('127.0.0.1', port: testPort);
      expect(server.isConnected, isTrue);

      final client = Client();
      await client.connect('ws://127.0.0.1:$testPort/ws');

      await Future.delayed(Duration(milliseconds: 500));
      expect(client.isConnected, isTrue);
      expect(server.clients.length, equals(1));

      await client.disconnect();
      await server.stop();
    });

    test('should accept connections with valid token', () async {
      server = Server(
        requestAuthenticationDelegate: RequestTokenAuthenticator(
          validTokens: {'secret123'},
        ),
      );
      await server.start('127.0.0.1', port: testPort);

      final client = Client(details: {'token': 'secret123'});
      await client.connect('ws://127.0.0.1:$testPort/ws');

      await Future.delayed(Duration(milliseconds: 500));
      expect(client.isConnected, isTrue);
      expect(server.clients.length, equals(1));

      await client.disconnect();
      await server.stop();
    });

    test('should reject connections with invalid token', () async {
      server = Server(
        requestAuthenticationDelegate: RequestTokenAuthenticator(
          validTokens: {'secret123'},
        ),
      );
      await server.start('127.0.0.1', port: testPort);

      final client = Client(details: {'token': 'wrong_token'});

      // Attempt connection - should fail
      try {
        await client.connect('ws://127.0.0.1:$testPort/ws');

        // Listen for errors and disconnection
        await client.messageStream.first.timeout(
          Duration(seconds: 1),
          onTimeout: () => null,
        );
      } on WebSocketChannelException catch (_) {
        // Expected - server returned non-101 response (403 Forbidden)
      } catch (e) {
        // Any other exception is also acceptable
      }

      // Give time for async cleanup
      await Future.delayed(Duration(milliseconds: 100));

      // The server should NOT have added this client
      expect(server.clients.length, equals(0),
          reason: 'Server should reject client with invalid token');

      await server.stop();
    });

    test('should reject connections with missing token', () async {
      server = Server(
        requestAuthenticationDelegate: RequestTokenAuthenticator(
          validTokens: {'secret123'},
        ),
      );
      await server.start('127.0.0.1', port: testPort);

      final client = Client();

      // Attempt connection - should fail
      try {
        await client.connect('ws://127.0.0.1:$testPort/ws');

        // Listen for errors and disconnection
        await client.messageStream.first.timeout(
          Duration(seconds: 1),
          onTimeout: () => null,
        );
      } on WebSocketChannelException catch (_) {
        // Expected - server returned non-101 response (401 Unauthorized)
      } catch (e) {
        // Any other exception is also acceptable
      }

      // Give time for async cleanup
      await Future.delayed(Duration(milliseconds: 100));

      // The server should NOT have added this client
      expect(server.clients.length, equals(0),
          reason: 'Server should reject client without token');

      await server.stop();
    });

    test('should work with IP authenticator', () async {
      server = Server(
        requestAuthenticationDelegate: RequestIPAuthenticator(
          allowedIPs: {'127.0.0.1'},
        ),
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

    test('should work with combined authenticators', () async {
      server = Server(
        requestAuthenticationDelegate: MultiRequestAuthenticator([
          RequestTokenAuthenticator(validTokens: {'token123'}),
          RequestIPAuthenticator(allowedIPs: {'127.0.0.1'}),
        ]),
      );
      await server.start('127.0.0.1', port: testPort);

      final client = Client(details: {'token': 'token123'});
      await client.connect('ws://127.0.0.1:$testPort/ws');

      await Future.delayed(Duration(milliseconds: 500));
      expect(client.isConnected, isTrue);
      expect(server.clients.length, equals(1));

      await client.disconnect();
      await server.stop();
    });
  });
}
