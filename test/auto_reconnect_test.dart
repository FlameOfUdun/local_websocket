import 'dart:async';
import 'package:test/test.dart';
import 'package:local_websocket/local_websocket.dart';

/// Mock reconnect delegate for testing
class MockReconnectDelegate implements ClientReconectionDelegate {
  final List<int> reconnectAttempts = [];
  final List<Duration> delays = [];
  int reconnectedCount = 0;
  int failedCount = 0;

  final int maxAttempts;
  final Duration delay;

  MockReconnectDelegate({
    this.maxAttempts = 3,
    this.delay = const Duration(milliseconds: 100),
  });

  @override
  Future<bool> shouldReconnect(
      int attemptNumber, Duration timeSinceLastConnect) async {
    reconnectAttempts.add(attemptNumber);
    return attemptNumber < maxAttempts;
  }

  @override
  Future<Duration> getReconnectDelay(int attemptNumber) async {
    delays.add(delay);
    return delay;
  }

  @override
  void onReconnected(int attemptNumber) {
    reconnectedCount++;
  }

  @override
  void onReconnectFailed(int totalAttempts) {
    failedCount++;
  }

  void reset() {
    reconnectAttempts.clear();
    delays.clear();
    reconnectedCount = 0;
    failedCount = 0;
  }
}

void main() {
  late Server server;
  late Client client;
  late MockReconnectDelegate reconnectDelegate;

  group('AutoReconnectDelegate', () {
    setUp(() async {
      server = Server(
        details: {
          'name': 'Test Server',
        },
      );

      reconnectDelegate = MockReconnectDelegate(
        maxAttempts: 3,
        delay: Duration(milliseconds: 100),
      );

      await server.start('127.0.0.1', port: 8888);
    });

    tearDown(() async {
      try {
        await client.disconnect();
      } catch (_) {}

      try {
        await server.stop();
      } catch (_) {}

      reconnectDelegate.reset();
    });

    test('should have ClientConnectionStatus enum values', () {
      expect(ClientConnectionStatus.values.length, 3);
      expect(ClientConnectionStatus.values,
          contains(ClientConnectionStatus.disconnected));
      expect(ClientConnectionStatus.values,
          contains(ClientConnectionStatus.connecting));
      expect(ClientConnectionStatus.values,
          contains(ClientConnectionStatus.connected));
    });

    test('client should start with disconnected status', () {
      client = Client(
        details: {'name': 'Test Client'},
        clientReconnectionDelegate: reconnectDelegate,
      );

      expect(client.connectionStatus, ClientConnectionStatus.disconnected);
    });

    test(
        'client should emit connecting and connected status on successful connect',
        () async {
      client = Client(
        details: {'name': 'Test Client'},
        clientReconnectionDelegate: reconnectDelegate,
      );

      final statuses = <ClientConnectionStatus>[];
      final subscription = client.connectionStream.listen(statuses.add);

      await client.connect('ws://127.0.0.1:8888/ws');

      // Give it a moment to emit all statuses
      await Future.delayed(Duration(milliseconds: 50));

      expect(statuses, contains(ClientConnectionStatus.connecting));
      expect(statuses, contains(ClientConnectionStatus.connected));
      expect(client.connectionStatus, ClientConnectionStatus.connected);

      await subscription.cancel();
    });

    test('should automatically reconnect when connection is lost', () async {
      client = Client(
        details: {'name': 'Test Client'},
        clientReconnectionDelegate: reconnectDelegate,
      );

      final statuses = <ClientConnectionStatus>[];
      final subscription = client.connectionStream.listen(statuses.add);

      // Connect client
      await client.connect('ws://127.0.0.1:8888/ws');
      await Future.delayed(Duration(milliseconds: 50));

      expect(client.connectionStatus, ClientConnectionStatus.connected);

      // Simulate connection loss by stopping server
      await server.stop();

      // Wait for reconnection attempts
      await Future.delayed(Duration(milliseconds: 500));

      // Should have tried to reconnect
      expect(reconnectDelegate.reconnectAttempts.isNotEmpty, isTrue);
      // Status should include connecting (auto-reconnect is active)
      expect(statuses, contains(ClientConnectionStatus.connecting));

      await subscription.cancel();
    });

    test('should call onReconnectFailed when max attempts reached', () async {
      // Use a very short delay to speed up the test
      final fastDelegate = MockReconnectDelegate(
        maxAttempts: 3,
        delay: Duration(milliseconds: 10),
      );

      client = Client(
        details: {'name': 'Test Client'},
        clientReconnectionDelegate: fastDelegate,
      );

      // Connect and then kill server
      await client.connect('ws://127.0.0.1:8888/ws');
      await Future.delayed(Duration(milliseconds: 100));

      await server.stop();

      // Wait for all reconnection attempts to fail
      // WebSocket.connect has a built-in timeout (several seconds per attempt)
      await Future.delayed(Duration(seconds: 10));

      // After max attempts, should call onReconnectFailed
      expect(fastDelegate.failedCount, 1,
          reason: 'Should call onReconnectFailed once');
      expect(fastDelegate.reconnectAttempts.length,
          greaterThanOrEqualTo(fastDelegate.maxAttempts),
          reason: 'Should attempt at least maxAttempts times');
    });

    test('should successfully reconnect when server comes back online',
        () async {
      client = Client(
        details: {'name': 'Test Client'},
        clientReconnectionDelegate: reconnectDelegate,
      );

      // Connect client
      await client.connect('ws://127.0.0.1:8888/ws');
      await Future.delayed(Duration(milliseconds: 50));

      expect(client.connectionStatus, ClientConnectionStatus.connected);

      // Stop server
      await server.stop();
      await Future.delayed(Duration(milliseconds: 50));

      // Should be in connecting status (auto-reconnect is active)
      expect(client.connectionStatus, ClientConnectionStatus.connecting);

      // Restart server quickly (before max attempts reached)
      await server.start('127.0.0.1', port: 8888);

      // Wait for reconnection
      await Future.delayed(Duration(milliseconds: 500));

      // Should have reconnected
      expect(client.connectionStatus, ClientConnectionStatus.connected);
      expect(reconnectDelegate.reconnectedCount, greaterThan(0));
    });

    test('should stop reconnecting when disconnect is called', () async {
      client = Client(
        details: {'name': 'Test Client'},
        clientReconnectionDelegate: reconnectDelegate,
      );

      // Connect client
      await client.connect('ws://127.0.0.1:8888/ws');
      await Future.delayed(Duration(milliseconds: 50));

      // Stop server to trigger reconnection
      await server.stop();
      await Future.delayed(Duration(milliseconds: 50));

      final attemptsBefore = reconnectDelegate.reconnectAttempts.length;

      // Explicitly disconnect
      await client.disconnect();

      // Wait a bit
      await Future.delayed(Duration(milliseconds: 300));

      // Should not have made many more attempts
      final attemptsAfter = reconnectDelegate.reconnectAttempts.length;
      expect(attemptsAfter - attemptsBefore, lessThan(2));
      expect(client.connectionStatus, ClientConnectionStatus.disconnected);
    });

    test('should respect delegate delay between reconnection attempts',
        () async {
      final customDelegate = MockReconnectDelegate(
        maxAttempts: 2,
        delay: Duration(milliseconds: 200),
      );

      client = Client(
        details: {'name': 'Test Client'},
        clientReconnectionDelegate: customDelegate,
      );

      // Connect and disconnect
      await client.connect('ws://127.0.0.1:8888/ws');
      await Future.delayed(Duration(milliseconds: 50));
      await server.stop();

      final startTime = DateTime.now();

      // Wait for attempts to complete
      await Future.delayed(Duration(milliseconds: 600));

      final elapsed = DateTime.now().difference(startTime);

      // Should have respected the delays
      expect(customDelegate.delays.isNotEmpty, isTrue);
      expect(elapsed.inMilliseconds, greaterThan(300));
    });
  });

  group('ExponentialBackoffReconnect', () {
    test('should create with default values', () {
      final delegate = ExponentialBackoffReconnect();

      expect(delegate.maxAttempts, 5);
      expect(delegate.initialDelay, Duration(seconds: 1));
      expect(delegate.maxDelay, Duration(seconds: 30));
      expect(delegate.multiplier, 2.0);
    });

    test('should return exponentially increasing delays', () async {
      final delegate = ExponentialBackoffReconnect(
        initialDelay: Duration(seconds: 1),
        multiplier: 2.0,
      );

      final delay0 = await delegate.getReconnectDelay(0);
      final delay1 = await delegate.getReconnectDelay(1);
      final delay2 = await delegate.getReconnectDelay(2);

      expect(delay0, Duration(seconds: 1));
      expect(delay1, Duration(seconds: 2));
      expect(delay2, Duration(seconds: 4));
    });

    test('should cap delay at maxDelay', () async {
      final delegate = ExponentialBackoffReconnect(
        initialDelay: Duration(seconds: 10),
        maxDelay: Duration(seconds: 15),
        multiplier: 2.0,
      );

      final delay0 = await delegate.getReconnectDelay(0);
      final delay1 = await delegate.getReconnectDelay(1);
      final delay2 = await delegate.getReconnectDelay(2);

      expect(delay0, Duration(seconds: 10));
      expect(delay1, Duration(seconds: 15)); // Capped at maxDelay
      expect(delay2, Duration(seconds: 15)); // Capped at maxDelay
    });

    test('should stop after maxAttempts', () async {
      final delegate = ExponentialBackoffReconnect(maxAttempts: 3);

      expect(await delegate.shouldReconnect(0, Duration.zero), isTrue);
      expect(await delegate.shouldReconnect(1, Duration.zero), isTrue);
      expect(await delegate.shouldReconnect(2, Duration.zero), isTrue);
      expect(await delegate.shouldReconnect(3, Duration.zero), isFalse);
      expect(await delegate.shouldReconnect(4, Duration.zero), isFalse);
    });
  });

  group('LinearBackoffReconnect', () {
    test('should create with default values', () {
      final delegate = LinearBackoffReconnect();

      expect(delegate.maxAttempts, 10);
      expect(delegate.interval, Duration(seconds: 2));
    });

    test('should return linearly increasing delays', () async {
      final delegate = LinearBackoffReconnect(
        interval: Duration(seconds: 2),
      );

      final delay0 = await delegate.getReconnectDelay(0);
      final delay1 = await delegate.getReconnectDelay(1);
      final delay2 = await delegate.getReconnectDelay(2);

      expect(delay0, Duration(seconds: 2));
      expect(delay1, Duration(seconds: 4));
      expect(delay2, Duration(seconds: 6));
    });

    test('should stop after maxAttempts', () async {
      final delegate = LinearBackoffReconnect(maxAttempts: 5);

      expect(await delegate.shouldReconnect(0, Duration.zero), isTrue);
      expect(await delegate.shouldReconnect(4, Duration.zero), isTrue);
      expect(await delegate.shouldReconnect(5, Duration.zero), isFalse);
    });
  });

  group('InfiniteReconnect', () {
    test('should create with default values', () {
      final delegate = InfiniteReconnect();

      expect(delegate.interval, Duration(seconds: 5));
    });

    test('should always return same delay', () async {
      final delegate = InfiniteReconnect(
        interval: Duration(seconds: 3),
      );

      final delay0 = await delegate.getReconnectDelay(0);
      final delay1 = await delegate.getReconnectDelay(1);
      final delay2 = await delegate.getReconnectDelay(10);

      expect(delay0, Duration(seconds: 3));
      expect(delay1, Duration(seconds: 3));
      expect(delay2, Duration(seconds: 3));
    });

    test('should always want to reconnect', () async {
      final delegate = InfiniteReconnect();

      expect(await delegate.shouldReconnect(0, Duration.zero), isTrue);
      expect(await delegate.shouldReconnect(100, Duration.zero), isTrue);
      expect(await delegate.shouldReconnect(1000, Duration.zero), isTrue);
    });
  });
}
