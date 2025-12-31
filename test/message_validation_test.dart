import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:local_websocket/local_websocket.dart';

void main() {
  group('MessageValidationDelegate', () {
    late Server server;
    const testPort = 8084;

    tearDown(() async {
      if (server.isConnected) {
        await server.stop();
      }
    });

    test('should allow all messages when validation returns true', () async {
      server = Server(
        echo: false,
        messageValidationDelegate: _AlwaysAllowValidator(),
      );
      await server.start('127.0.0.1', port: testPort);

      final client1 = Client(details: {'name': 'Sender'});
      final client2 = Client(details: {'name': 'Receiver'});

      await client1.connect('ws://127.0.0.1:$testPort/ws');
      await client2.connect('ws://127.0.0.1:$testPort/ws');
      await Future.delayed(Duration(milliseconds: 500));

      final receivedMessages = <dynamic>[];
      client2.messageStream.listen((message) {
        receivedMessages.add(message);
      });

      client1.send('Test message');
      await Future.delayed(Duration(milliseconds: 500));

      expect(receivedMessages.length, equals(1));
      expect(receivedMessages.first, equals('Test message'));

      await client1.disconnect();
      await client2.disconnect();
      await server.stop();
    });

    test('should block all messages when validation returns false', () async {
      server = Server(
        echo: false,
        messageValidationDelegate: _AlwaysDenyValidator(),
      );
      await server.start('127.0.0.1', port: testPort);

      final client1 = Client(details: {'name': 'Sender'});
      final client2 = Client(details: {'name': 'Receiver'});

      await client1.connect('ws://127.0.0.1:$testPort/ws');
      await client2.connect('ws://127.0.0.1:$testPort/ws');
      await Future.delayed(Duration(milliseconds: 500));

      final receivedMessages = <dynamic>[];
      client2.messageStream.listen((message) {
        receivedMessages.add(message);
      });

      client1.send('This should be blocked');
      await Future.delayed(Duration(milliseconds: 500));

      // No messages should be received
      expect(receivedMessages, isEmpty);

      await client1.disconnect();
      await client2.disconnect();
      await server.stop();
    });

    test('should filter profanity from messages', () async {
      server = Server(
        echo: false,
        messageValidationDelegate: _ProfanityFilter(),
      );
      await server.start('127.0.0.1', port: testPort);

      final client1 = Client(details: {'name': 'Sender'});
      final client2 = Client(details: {'name': 'Receiver'});

      await client1.connect('ws://127.0.0.1:$testPort/ws');
      await client2.connect('ws://127.0.0.1:$testPort/ws');
      await Future.delayed(Duration(milliseconds: 500));

      final receivedMessages = <dynamic>[];
      client2.messageStream.listen((message) {
        receivedMessages.add(message);
      });

      // Send clean message
      client1.send('Hello world');
      await Future.delayed(Duration(milliseconds: 300));
      expect(receivedMessages.length, equals(1));

      // Send message with profanity
      client1.send('This contains badword and should be blocked');
      await Future.delayed(Duration(milliseconds: 300));

      // Should still only have 1 message (the clean one)
      expect(receivedMessages.length, equals(1));

      await client1.disconnect();
      await client2.disconnect();
      await server.stop();
    });

    test('should enforce rate limiting', () async {
      server = Server(
        echo: false,
        messageValidationDelegate: _RateLimiter(
          maxMessages: 3,
          timeWindow: Duration(seconds: 2),
        ),
      );
      await server.start('127.0.0.1', port: testPort);

      final client1 = Client(details: {'name': 'Sender'});
      final client2 = Client(details: {'name': 'Receiver'});

      await client1.connect('ws://127.0.0.1:$testPort/ws');
      await client2.connect('ws://127.0.0.1:$testPort/ws');
      await Future.delayed(Duration(milliseconds: 500));

      final receivedMessages = <dynamic>[];
      client2.messageStream.listen((message) {
        receivedMessages.add(message);
      });

      // Send 3 messages quickly (should all pass)
      client1.send('Message 1');
      await Future.delayed(Duration(milliseconds: 100));
      client1.send('Message 2');
      await Future.delayed(Duration(milliseconds: 100));
      client1.send('Message 3');
      await Future.delayed(Duration(milliseconds: 500));

      expect(receivedMessages.length, equals(3));

      // Try to send more messages (should be rate limited)
      client1.send('Message 4 - rate limited');
      client1.send('Message 5 - rate limited');
      await Future.delayed(Duration(milliseconds: 500));

      // Should still only have 3 messages
      expect(receivedMessages.length, equals(3));

      await client1.disconnect();
      await client2.disconnect();
      await server.stop();
    });

    test('should validate message format', () async {
      server = Server(
        echo: false,
        messageValidationDelegate: _MessageFormatValidator(),
      );
      await server.start('127.0.0.1', port: testPort);

      final client1 = Client(details: {'name': 'Sender'});
      final client2 = Client(details: {'name': 'Receiver'});

      await client1.connect('ws://127.0.0.1:$testPort/ws');
      await client2.connect('ws://127.0.0.1:$testPort/ws');
      await Future.delayed(Duration(milliseconds: 500));

      final receivedMessages = <dynamic>[];
      client2.messageStream.listen((message) {
        receivedMessages.add(message);
      });

      // Send valid JSON message with 'type' field
      final validMessage = jsonEncode({'type': 'chat', 'text': 'Hello'});
      client1.send(validMessage);
      await Future.delayed(Duration(milliseconds: 300));
      expect(receivedMessages.length, equals(1));

      // Send invalid message (not JSON)
      client1.send('Not a JSON message');
      await Future.delayed(Duration(milliseconds: 300));

      // Should still only have 1 message
      expect(receivedMessages.length, equals(1));

      // Send JSON without 'type' field
      final invalidMessage = jsonEncode({'text': 'Missing type'});
      client1.send(invalidMessage);
      await Future.delayed(Duration(milliseconds: 300));

      // Should still only have 1 message
      expect(receivedMessages.length, equals(1));

      await client1.disconnect();
      await client2.disconnect();
      await server.stop();
    });

    test('should validate message length', () async {
      server = Server(
        echo: false,
        messageValidationDelegate: _MessageLengthValidator(maxLength: 20),
      );
      await server.start('127.0.0.1', port: testPort);

      final client1 = Client(details: {'name': 'Sender'});
      final client2 = Client(details: {'name': 'Receiver'});

      await client1.connect('ws://127.0.0.1:$testPort/ws');
      await client2.connect('ws://127.0.0.1:$testPort/ws');
      await Future.delayed(Duration(milliseconds: 500));

      final receivedMessages = <dynamic>[];
      client2.messageStream.listen((message) {
        receivedMessages.add(message);
      });

      // Send short message
      client1.send('Short');
      await Future.delayed(Duration(milliseconds: 300));
      expect(receivedMessages.length, equals(1));

      // Send long message (should be rejected)
      client1
          .send('This is a very long message that exceeds the maximum length');
      await Future.delayed(Duration(milliseconds: 300));

      // Should still only have 1 message
      expect(receivedMessages.length, equals(1));

      await client1.disconnect();
      await client2.disconnect();
      await server.stop();
    });

    test('should validate messages per client', () async {
      server = Server(
        echo: false,
        messageValidationDelegate: _PerClientValidator(),
      );
      await server.start('127.0.0.1', port: testPort);

      final client1 = Client(details: {'name': 'Sender', 'role': 'admin'});
      final client2 = Client(details: {'name': 'Sender2', 'role': 'user'});
      final client3 = Client(details: {'name': 'Receiver'});

      await client1.connect('ws://127.0.0.1:$testPort/ws');
      await client2.connect('ws://127.0.0.1:$testPort/ws');
      await client3.connect('ws://127.0.0.1:$testPort/ws');
      await Future.delayed(Duration(milliseconds: 500));

      final receivedMessages = <dynamic>[];
      client3.messageStream.listen((message) {
        receivedMessages.add(message);
      });

      // Admin can send messages
      client1.send('Message from admin');
      await Future.delayed(Duration(milliseconds: 300));
      expect(receivedMessages.length, equals(1));

      // Regular user cannot send messages
      client2.send('Message from user - blocked');
      await Future.delayed(Duration(milliseconds: 300));

      // Should still only have 1 message (from admin)
      expect(receivedMessages.length, equals(1));

      await client1.disconnect();
      await client2.disconnect();
      await client3.disconnect();
      await server.stop();
    });
  });
}

// Test message validators

class _AlwaysAllowValidator implements MessageValidationDelegate {
  @override
  Future<bool> validateMessage(Client client, String message) async {
    return true;
  }
}

class _AlwaysDenyValidator implements MessageValidationDelegate {
  @override
  Future<bool> validateMessage(Client client, String message) async {
    return false;
  }
}

class _ProfanityFilter implements MessageValidationDelegate {
  final Set<String> bannedWords = {'badword', 'offensive', 'inappropriate'};

  @override
  Future<bool> validateMessage(Client client, String message) async {
    final lowerMessage = message.toString().toLowerCase();

    for (final word in bannedWords) {
      if (lowerMessage.contains(word)) {
        return false;
      }
    }

    return true;
  }
}

class _RateLimiter implements MessageValidationDelegate {
  final Map<String, List<DateTime>> _messageTimes = {};
  final int maxMessages;
  final Duration timeWindow;

  _RateLimiter({
    required this.maxMessages,
    required this.timeWindow,
  });

  @override
  Future<bool> validateMessage(Client client, String message) async {
    final now = DateTime.now();
    final clientId = client.uid;

    _messageTimes.putIfAbsent(clientId, () => []);

    // Remove old messages outside time window
    _messageTimes[clientId]!.removeWhere(
      (time) => now.difference(time) > timeWindow,
    );

    // Check if limit exceeded
    if (_messageTimes[clientId]!.length >= maxMessages) {
      return false;
    }

    // Add this message
    _messageTimes[clientId]!.add(now);
    return true;
  }
}

class _MessageFormatValidator implements MessageValidationDelegate {
  @override
  Future<bool> validateMessage(Client client, String message) async {
    try {
      final decoded = jsonDecode(message);

      if (decoded is! Map) {
        return false;
      }

      if (!decoded.containsKey('type')) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}

class _MessageLengthValidator implements MessageValidationDelegate {
  final int maxLength;

  _MessageLengthValidator({required this.maxLength});

  @override
  Future<bool> validateMessage(Client client, String message) async {
    return message.length <= maxLength;
  }
}

class _PerClientValidator implements MessageValidationDelegate {
  @override
  Future<bool> validateMessage(Client client, String message) async {
    // Only allow messages from admin users
    final role = client.details['role'];
    return role == 'admin';
  }
}
