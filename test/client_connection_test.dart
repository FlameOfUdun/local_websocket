import 'dart:async';

import 'package:test/test.dart';
import 'package:local_websocket/local_websocket.dart';

void main() {
  group('ClientConnectionDelegate', () {
    late Server server;
    const testPort = 8083;

    tearDown(() async {
      if (server.isConnected) {
        await server.stop();
      }
    });

    test('should call onClientConnected when client connects', () async {
      final tracker = _ConnectionTracker();
      server = Server(
        clientConnectionDelegate: tracker,
      );
      await server.start('127.0.0.1', port: testPort);

      expect(tracker.connectedClients, isEmpty);
      expect(tracker.disconnectedClients, isEmpty);

      final client = Client(details: {'username': 'Alice'});
      await client.connect('ws://127.0.0.1:$testPort/ws');

      // Wait for connection callback to execute
      await Future.delayed(Duration(milliseconds: 500));

      expect(tracker.connectedClients.length, equals(1));
      expect(
          tracker.connectedClients.first.details['username'], equals('Alice'));
      expect(tracker.disconnectedClients, isEmpty);

      await client.disconnect();
      await server.stop();
    });

    test('should call onClientDisconnected when client disconnects', () async {
      final tracker = _ConnectionTracker();
      server = Server(
        clientConnectionDelegate: tracker,
      );
      await server.start('127.0.0.1', port: testPort);

      final client = Client(details: {'username': 'Bob'});
      await client.connect('ws://127.0.0.1:$testPort/ws');

      await Future.delayed(Duration(milliseconds: 500));
      expect(tracker.connectedClients.length, equals(1));

      await client.disconnect();
      await Future.delayed(Duration(milliseconds: 500));

      expect(tracker.disconnectedClients.length, equals(1));
      expect(
          tracker.disconnectedClients.first.details['username'], equals('Bob'));

      await server.stop();
    });

    test('should track multiple clients connecting and disconnecting',
        () async {
      final tracker = _ConnectionTracker();
      server = Server(
        clientConnectionDelegate: tracker,
      );
      await server.start('127.0.0.1', port: testPort);

      // Connect 3 clients
      final client1 = Client(details: {'username': 'Alice'});
      final client2 = Client(details: {'username': 'Bob'});
      final client3 = Client(details: {'username': 'Charlie'});

      await client1.connect('ws://127.0.0.1:$testPort/ws');
      await Future.delayed(Duration(milliseconds: 300));
      await client2.connect('ws://127.0.0.1:$testPort/ws');
      await Future.delayed(Duration(milliseconds: 300));
      await client3.connect('ws://127.0.0.1:$testPort/ws');
      await Future.delayed(Duration(milliseconds: 300));

      expect(tracker.connectedClients.length, equals(3));
      expect(tracker.disconnectedClients.length, equals(0));

      // Disconnect one client
      await client2.disconnect();
      await Future.delayed(Duration(milliseconds: 500));

      expect(tracker.disconnectedClients.length, equals(1));
      expect(
          tracker.disconnectedClients.first.details['username'], equals('Bob'));

      await client1.disconnect();
      await client3.disconnect();
      await server.stop();
    });

    test('should call onClientDisconnected when server stops', () async {
      final tracker = _ConnectionTracker();
      server = Server(
        clientConnectionDelegate: tracker,
      );
      await server.start('127.0.0.1', port: testPort);

      final client1 = Client(details: {'username': 'Alice'});
      final client2 = Client(details: {'username': 'Bob'});

      await client1.connect('ws://127.0.0.1:$testPort/ws');
      await client2.connect('ws://127.0.0.1:$testPort/ws');
      await Future.delayed(Duration(milliseconds: 500));

      expect(tracker.connectedClients.length, equals(2));
      expect(tracker.disconnectedClients.length, equals(0));

      // Stop server - should disconnect all clients
      await server.stop();
      await Future.delayed(Duration(milliseconds: 500));

      // Both clients should be disconnected
      expect(tracker.disconnectedClients.length, equals(2));
    });

    test('should log connection events', () async {
      final logger = _ConnectionLogger();
      server = Server(
        clientConnectionDelegate: logger,
      );
      await server.start('127.0.0.1', port: testPort);

      final client = Client(details: {'username': 'TestUser'});
      await client.connect('ws://127.0.0.1:$testPort/ws');
      await Future.delayed(Duration(milliseconds: 500));

      expect(logger.logs.length, greaterThanOrEqualTo(1));
      expect(logger.logs.any((log) => log.contains('connected')), isTrue);
      expect(logger.logs.any((log) => log.contains('TestUser')), isTrue);

      await client.disconnect();
      await Future.delayed(Duration(milliseconds: 500));

      expect(logger.logs.any((log) => log.contains('disconnected')), isTrue);

      await server.stop();
    });

    test('should send join/leave announcements', () async {
      final announcer = _JoinLeaveAnnouncer();
      server = Server(
        clientConnectionDelegate: announcer,
      );
      await server.start('127.0.0.1', port: testPort);

      final client1 = Client(details: {'username': 'Alice'});
      final client2 = Client(details: {'username': 'Bob'});

      // Setup message listener on client2 before client1 joins
      final receivedMessages = <dynamic>[];

      await client2.connect('ws://127.0.0.1:$testPort/ws');
      await Future.delayed(Duration(milliseconds: 300));

      client2.messageStream.listen((message) {
        receivedMessages.add(message);
      });

      // Now connect client1 - client2 should receive join announcement
      await client1.connect('ws://127.0.0.1:$testPort/ws');
      await Future.delayed(Duration(milliseconds: 500));

      // Check that announcements were made
      expect(announcer.joinedUsers.length, equals(2));
      expect(announcer.leftUsers.length, equals(0));

      await client1.disconnect();
      await Future.delayed(Duration(milliseconds: 500));

      expect(announcer.leftUsers.length, equals(1));
      expect(announcer.leftUsers.first, equals('Alice'));

      await client2.disconnect();
      await server.stop();
    });
  });
}

// Test connection delegates

class _ConnectionTracker implements ClientConnectionDelegate {
  final List<Client> connectedClients = [];
  final List<Client> disconnectedClients = [];

  @override
  Future<void> onClientConnected(Client client) async {
    connectedClients.add(client);
  }

  @override
  Future<void> onClientDisconnected(Client client) async {
    disconnectedClients.add(client);
  }
}

class _ConnectionLogger implements ClientConnectionDelegate {
  final List<String> logs = [];

  @override
  Future<void> onClientConnected(Client client) async {
    final username = client.details['username'] ?? 'Unknown';
    final logMessage = 'Client connected: $username (${client.uid})';
    logs.add(logMessage);
  }

  @override
  Future<void> onClientDisconnected(Client client) async {
    final username = client.details['username'] ?? 'Unknown';
    final logMessage = 'Client disconnected: $username (${client.uid})';
    logs.add(logMessage);
  }
}

class _JoinLeaveAnnouncer implements ClientConnectionDelegate {
  final List<String> joinedUsers = [];
  final List<String> leftUsers = [];

  @override
  Future<void> onClientConnected(Client client) async {
    final username = client.details['username'] ?? 'Anonymous';
    joinedUsers.add(username);
  }

  @override
  Future<void> onClientDisconnected(Client client) async {
    final username = client.details['username'] ?? 'Anonymous';
    leftUsers.add(username);
  }
}
