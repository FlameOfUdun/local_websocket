part of '../source.dart';

/// An abstract class that defines the contract for authenticating incoming requests.
abstract interface class RequestAuthenticationDelegate {
  /// Authenticates the given [request] and returns an [RequestAuthenticationResult].
  FutureOr<RequestAuthenticationResult> authenticateRequest(Request request);
}

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

/// Simple token-based request authenticator.
final class RequestTokenAuthenticator implements RequestAuthenticationDelegate {
  /// The set of valid tokens.
  final Set<String> validTokens;

  /// The name of the query parameter to look for the token.
  final String parameterName;

  const RequestTokenAuthenticator({
    required this.validTokens,
    this.parameterName = 'token',
  });

  @override
  Future<RequestAuthenticationResult> authenticateRequest(
      Request request) async {
    final token = request.url.queryParameters[parameterName];

    if (token == null || token.isEmpty) {
      return RequestAuthenticationResult.failure(
        reason: 'Missing $parameterName parameter',
        statusCode: 401,
      );
    }

    if (!validTokens.contains(token)) {
      return RequestAuthenticationResult.failure(
        reason: 'Invalid $parameterName',
        statusCode: 403,
      );
    }

    return RequestAuthenticationResult.success(
      metadata: {parameterName: token},
    );
  }
}

/// Header-based request authenticator.
final class RequestHeaderAuthenticator
    implements RequestAuthenticationDelegate {
  /// The name of the header to validate.
  final String headerName;

  /// The set of valid header values.
  final Set<String> validValues;

  /// Whether the header value comparison is case-sensitive.
  final bool caseSensitive;

  const RequestHeaderAuthenticator({
    required this.headerName,
    required this.validValues,
    this.caseSensitive = true,
  });

  @override
  Future<RequestAuthenticationResult> authenticateRequest(
      Request request) async {
    final headerValue = request.headers[headerName.toLowerCase()];

    if (headerValue == null || headerValue.isEmpty) {
      return RequestAuthenticationResult.failure(
        reason: 'Missing $headerName header',
        statusCode: 401,
      );
    }

    final isValid = caseSensitive
        ? validValues.contains(headerValue)
        : validValues.any((v) => v.toLowerCase() == headerValue.toLowerCase());

    if (!isValid) {
      return RequestAuthenticationResult.failure(
        reason: 'Invalid $headerName',
        statusCode: 403,
      );
    }

    return RequestAuthenticationResult.success(
      metadata: {headerName: headerValue},
    );
  }
}

/// IP-based request authenticator.
final class RequestIPAuthenticator implements RequestAuthenticationDelegate {
  /// The set of allowed IP addresses.
  final Set<String> allowedIPs;

  const RequestIPAuthenticator({
    required this.allowedIPs,
  });

  @override
  Future<RequestAuthenticationResult> authenticateRequest(
      Request request) async {
    final connectionInfo =
        request.context['shelf.io.connection_info'] as HttpConnectionInfo?;

    if (connectionInfo == null) {
      return RequestAuthenticationResult.failure(
        reason: 'Unable to determine client IP',
        statusCode: 500,
      );
    }

    final clientIP = connectionInfo.remoteAddress.address;

    if (!allowedIPs.contains(clientIP)) {
      return RequestAuthenticationResult.failure(
        reason: 'IP address not allowed',
        statusCode: 403,
      );
    }

    return RequestAuthenticationResult.success(
      metadata: {'ip': clientIP},
    );
  }
}

/// Combines multiple authenticators into one.
final class MultiRequestAuthenticator implements RequestAuthenticationDelegate {
  /// The list of authenticators to combine.
  final List<RequestAuthenticationDelegate> authenticators;

  const MultiRequestAuthenticator(this.authenticators);

  @override
  Future<RequestAuthenticationResult> authenticateRequest(
      Request request) async {
    for (final auth in authenticators) {
      final result = await auth.authenticateRequest(request);
      if (!result.isSuccess) {
        return result;
      }
    }
    return RequestAuthenticationResult.success();
  }
}
