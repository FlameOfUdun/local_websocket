part of '../source.dart';

/// Abstract class that defines the contract for handling client connections
abstract class ClientConnectionDelegate {
  /// Called when a new client connects via WebSocket
  FutureOr<void> onClientConnected(Client client);

  /// Called when a client disconnects
  FutureOr<void> onClientDisconnected(Client client);
}
