part of '../source.dart';

/// Represents the current connection status of a client
enum ClientConnectionStatus {
  /// Client is disconnected from the server
  disconnected,

  /// Client is attempting to connect to the server
  connecting,

  /// Client is connected to the server
  connected;

  bool get isConnected => this == ClientConnectionStatus.connected;
  bool get isConnecting => this == ClientConnectionStatus.connecting;
  bool get isDisconnected => this == ClientConnectionStatus.disconnected;
}
