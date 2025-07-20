import 'package:test/test.dart';

import 'package:flutter_local_websocket/flutter_local_websocket.dart';

void main() {
  late Server server;
  late Client client;

  group('Scanner', () {
    setUp(() {
      server = Server(
        details: {
          'name': 'Test Server',
          'description': 'A test server for unit testing',
        },
      );

      client = Client(
        details: {
          'name': 'Test Client',
          'description': 'A test client for unit testing',
        },
      );
    });

    tearDown(() {
      server.stop().ignore();
    });

    test('should start and stop server', () async {
      expect(server.isConnected, isFalse);
      await server.start('127.0.0.1');
      expect(server.isConnected, isTrue);
      await server.stop();
      expect(server.isConnected, isFalse);
    });

    test('should throw error when trying to start an already running server', () async {
      await server.start('127.0.0.1');
      expect(() => server.start('127.0.0.1'), throwsStateError);
    });

    test('should throw error when trying to stop a server that is not running', () async {
      expect(() => server.stop(), throwsStateError);
    });

    test('should return correct address when server is running', () async {
      await server.start('127.0.0.1');
      expect(server.address, isA<Uri>());
      expect(server.address.host, '127.0.0.1');
      expect(server.address.port, greaterThan(0));
    });

    test('scanner should find the server', () async {
      await server.start('127.0.0.1');
      final discovered = await Scanner.scan("127.0.0.1");
      expect(discovered, isNotEmpty);
      expect(discovered.first.path, equals('ws://127.0.0.1:8080/ws'));
    });

    test('should connect/disconnect client', () async {
      await server.start('127.0.0.1');
      expect(server.clients, isEmpty);

      await client.connect('ws://127.0.0.1:8080/ws');
      expect(client.isConnected, isTrue);
      
      await Future.delayed(Duration(seconds: 1));
      expect(server.clients, isNotEmpty);
      
      await client.disconnect();
      await Future.delayed(Duration(seconds: 1));
      expect(client.isConnected, isFalse);
      expect(server.clients, isEmpty);
    });

    test('should disconnect client on stop', () async {
      await server.start('127.0.0.1');
      expect(server.clients, isEmpty);

      await client.connect('ws://127.0.0.1:8080/ws');
      expect(client.isConnected, isTrue);
      
      await Future.delayed(Duration(seconds: 1));
      expect(server.clients, isNotEmpty);
      
      await server.stop();
      await Future.delayed(Duration(seconds: 1));
      expect(client.isConnected, isFalse);
      expect(server.clients, isEmpty);
    });

    test('should send messages between server and client', () async {
      await server.start('127.0.0.1');
      server.messageStream.listen((message) {
        expect(message, 'Hello from Client');
      });

      await Future.delayed(Duration(seconds: 1));
      
      await client.connect('ws://127.0.0.1:8080/ws');
      client.messageStream.listen((message) {
        expect(message, 'Hello from Server');
      });

      await Future.delayed(Duration(seconds: 1));

      client.send('Hello from Client');
      
      await Future.delayed(Duration(seconds: 1));

      server.send('Hello from Server');

      await Future.delayed(Duration(seconds: 1));

      await client.disconnect();
      await server.stop();
      expect(client.isConnected, isFalse);
      expect(server.isConnected, isFalse);
    });
  });
}