part of '../source.dart';

/// An abstract class that defines the contract for handling client connections.
abstract interface class ClientConnectionDelegate {
  /// Called when a new client connects via WebSocket.
  ///
  /// The [channel] represents the WebSocket connection to the client.
  FutureOr<void> onClientConnected(Client client);

  /// Called when a client disconnects.
  FutureOr<void> onClientDisconnected(Client client);
}
