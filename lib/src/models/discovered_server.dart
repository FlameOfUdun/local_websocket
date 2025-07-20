final class DiscoveredServer {
  final String path;
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
