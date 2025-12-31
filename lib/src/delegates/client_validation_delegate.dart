part of '../source.dart';

/// Abstract class that defines the contract for validating clients
abstract class ClientValidationDelegate {
  /// Validates a [client] based on the incoming [request]
  /// Returns true if the client is valid, false otherwise
  FutureOr<bool> validateClient(Client client, HttpRequest request);
}
