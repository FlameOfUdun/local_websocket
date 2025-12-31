part of '../source.dart';

/// Result of an authentication attempt.
final class RequestAuthenticationResult {
  /// Indicates whether the authentication was successful.
  final bool isSuccess;

  /// Optional reason for failure or additional metadata.
  final String? reason;

  /// Optional metadata associated with the authentication.
  final Map<String, dynamic>? metadata;

  /// Optional HTTP status code to return on failure.
  final int? statusCode;

  const RequestAuthenticationResult._({
    required this.isSuccess,
    this.reason,
    this.metadata,
    this.statusCode,
  });

  /// Create a successful authentication result.
  ///
  /// Optionally provide [metadata] that will be available to other hooks.
  factory RequestAuthenticationResult.success({
    Map<String, dynamic>? metadata,
  }) {
    return RequestAuthenticationResult._(
      isSuccess: true,
      metadata: metadata,
    );
  }

  /// Create a failed authentication result.
  ///
  /// Provide a [reason] for logging/debugging.
  /// Optionally specify a [statusCode] (defaults to 403 Forbidden).
  factory RequestAuthenticationResult.failure({
    String? reason,
    int statusCode = 403,
  }) {
    return RequestAuthenticationResult._(
      isSuccess: false,
      reason: reason,
      statusCode: statusCode,
    );
  }

  /// Create a successful result with no authentication required.
  factory RequestAuthenticationResult.allow() {
    return RequestAuthenticationResult._(isSuccess: true);
  }

  /// Create a failed result with default forbidden message.
  factory RequestAuthenticationResult.deny() {
    return RequestAuthenticationResult._(
      isSuccess: false,
      reason: 'Access denied',
      statusCode: 403,
    );
  }
}
