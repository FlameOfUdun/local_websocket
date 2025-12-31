part of '../source.dart';

/// Abstract class that defines the contract for authenticating incoming requests
abstract interface class RequestAuthenticationDelegate {
  /// Authenticates the given [request] and returns a [RequestAuthenticationResult]
  FutureOr<RequestAuthenticationResult> authenticateRequest(
      HttpRequest request);
}

/// Simple token-based request authenticator
final class RequestTokenAuthenticator implements RequestAuthenticationDelegate {
  /// The set of valid tokens
  final Set<String> validTokens;

  /// The name of the query parameter to look for the token
  final String parameterName;

  const RequestTokenAuthenticator({
    required this.validTokens,
    this.parameterName = 'token',
  });

  @override
  Future<RequestAuthenticationResult> authenticateRequest(
      HttpRequest request) async {
    final token = request.uri.queryParameters[parameterName];

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

/// Header-based request authenticator
final class RequestHeaderAuthenticator
    implements RequestAuthenticationDelegate {
  /// The name of the header to validate
  final String headerName;

  /// The set of valid header values
  final Set<String> validValues;

  /// Whether the header value comparison is case-sensitive
  final bool caseSensitive;

  const RequestHeaderAuthenticator({
    required this.headerName,
    required this.validValues,
    this.caseSensitive = true,
  });

  @override
  Future<RequestAuthenticationResult> authenticateRequest(
      HttpRequest request) async {
    final headerValue = request.headers.value(headerName);

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

/// IP-based request authenticator
final class RequestIPAuthenticator implements RequestAuthenticationDelegate {
  /// The set of allowed IP addresses
  final Set<String> allowedIPs;

  const RequestIPAuthenticator({
    required this.allowedIPs,
  });

  @override
  Future<RequestAuthenticationResult> authenticateRequest(
      HttpRequest request) async {
    final clientIP = request.connectionInfo?.remoteAddress.address;

    if (clientIP == null) {
      return RequestAuthenticationResult.failure(
        reason: 'Unable to determine client IP',
        statusCode: 500,
      );
    }

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
