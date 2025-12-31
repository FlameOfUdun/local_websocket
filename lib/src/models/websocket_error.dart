part of '../source.dart';

/// Unified error model for WebSocket operations
class WebSocketError implements Exception {
  /// The error code (e.g., 'AUTH_FAILED', 'CONNECTION_REFUSED')
  final String code;

  /// Human-readable error message
  final String message;

  /// HTTP status code if applicable
  final int? statusCode;

  /// Additional error details/metadata
  final Map<String, dynamic>? details;

  /// Original exception if this wraps another error
  final Object? originalError;

  const WebSocketError({
    required this.code,
    required this.message,
    this.statusCode,
    this.details,
    this.originalError,
  });

  /// Factory for authentication errors
  factory WebSocketError.authenticationFailed({
    required String message,
    int? statusCode,
    Map<String, dynamic>? details,
  }) {
    return WebSocketError(
      code: 'AUTHENTICATION_FAILED',
      message: message,
      statusCode: statusCode,
      details: details,
    );
  }

  /// Factory for connection errors
  factory WebSocketError.connectionFailed({
    required String message,
    Object? originalError,
  }) {
    return WebSocketError(
      code: 'CONNECTION_FAILED',
      message: message,
      originalError: originalError,
    );
  }

  /// Factory for validation errors
  factory WebSocketError.validationFailed({
    required String message,
    Map<String, dynamic>? details,
  }) {
    return WebSocketError(
      code: 'VALIDATION_FAILED',
      message: message,
      details: details,
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer('WebSocketError: [$code] $message');
    if (statusCode != null) {
      buffer.write(' (HTTP $statusCode)');
    }
    if (details != null && details!.isNotEmpty) {
      buffer.write('\nDetails: $details');
    }
    return buffer.toString();
  }
}
