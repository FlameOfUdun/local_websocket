part of '../source.dart';

/// Represents a WebSocket server discovered on the network.
final class DiscoveredServer {
  /// The path to connect to the discovered server.
  final String path;

  /// Additional details about the discovered server.
  final Map<String, dynamic> details;

  const DiscoveredServer({
    required this.path,
    this.details = const {},
  });

  @override
  String toString() {
    return 'Session(path: $path, details: $details)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiscoveredServer && other.path == path;
  }

  @override
  int get hashCode => path.hashCode;
}
