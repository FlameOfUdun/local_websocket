part of '../source.dart';

/// Delegate for handling automatic reconnection logic
abstract interface class ClientReconectionDelegate {
  /// Called when the client disconnects unexpectedly
  /// Returns whether to attempt reconnection
  FutureOr<bool> shouldReconnect(
      int attemptNumber, Duration timeSinceLastConnect);

  /// Called before each reconnection attempt
  /// Returns the delay before attempting to reconnect
  FutureOr<Duration> getReconnectDelay(int attemptNumber);

  /// Called when reconnection succeeds
  void onReconnected(int attemptNumber);

  /// Called when reconnection fails after all attempts
  void onReconnectFailed(int totalAttempts);
}

/// Reconnects with exponential backoff (1s, 2s, 4s, 8s, ...)
final class ExponentialBackoffReconnect implements ClientReconectionDelegate {
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double multiplier;

  const ExponentialBackoffReconnect({
    this.maxAttempts = 5,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.multiplier = 2.0,
  });

  @override
  Future<bool> shouldReconnect(
      int attemptNumber, Duration timeSinceLastConnect) async {
    return attemptNumber < maxAttempts;
  }

  @override
  Future<Duration> getReconnectDelay(int attemptNumber) async {
    final delay = initialDelay * pow(multiplier, attemptNumber).toInt();
    return delay > maxDelay ? maxDelay : delay;
  }

  @override
  void onReconnected(int attemptNumber) {
    print('Reconnected after $attemptNumber attempts');
  }

  @override
  void onReconnectFailed(int totalAttempts) {
    print('Failed to reconnect after $totalAttempts attempts');
  }
}

/// Reconnects with linear backoff (2s, 4s, 6s, 8s, ...)
final class LinearBackoffReconnect implements ClientReconectionDelegate {
  final int maxAttempts;
  final Duration interval;

  const LinearBackoffReconnect({
    this.maxAttempts = 10,
    this.interval = const Duration(seconds: 2),
  });

  @override
  Future<bool> shouldReconnect(
      int attemptNumber, Duration timeSinceLastConnect) async {
    return attemptNumber < maxAttempts;
  }

  @override
  Future<Duration> getReconnectDelay(int attemptNumber) async {
    return interval * (attemptNumber + 1);
  }

  @override
  void onReconnected(int attemptNumber) {
    print('Reconnected after $attemptNumber attempts');
  }

  @override
  void onReconnectFailed(int totalAttempts) {
    print('Failed to reconnect after $totalAttempts attempts');
  }
}

/// Keeps trying to reconnect indefinitely with fixed interval
final class InfiniteReconnect implements ClientReconectionDelegate {
  final Duration interval;

  const InfiniteReconnect({
    this.interval = const Duration(seconds: 5),
  });

  @override
  Future<bool> shouldReconnect(
      int attemptNumber, Duration timeSinceLastConnect) async {
    return true; // Always reconnect
  }

  @override
  Future<Duration> getReconnectDelay(int attemptNumber) async {
    return interval;
  }

  @override
  void onReconnected(int attemptNumber) {
    print('Reconnected after $attemptNumber attempts');
  }

  @override
  void onReconnectFailed(int totalAttempts) {
    // Never called since this strategy never gives up
  }
}
