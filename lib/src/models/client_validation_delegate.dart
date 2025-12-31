part of '../source.dart';

/// Represents the result of client validation.
abstract class ClientValidationDelegate {
  /// Validates a [client] based on the incoming [request].
  FutureOr<bool> validateClient(Client client, Request request);
}
