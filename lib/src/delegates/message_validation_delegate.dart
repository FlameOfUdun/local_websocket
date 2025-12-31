part of '../source.dart';

/// An abstract class that defines the contract for validating messages from clients.
abstract interface class MessageValidationDelegate {
  /// Validates an incoming message from a client.
  ///
  /// Returns `true` if the message is valid, otherwise returns `false`.
  FutureOr<bool> validateMessage(Client client, String message);
}
