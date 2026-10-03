import 'package:dio/dio.dart';

/// Expected API failures. UI code switches on these instead of raw HTTP.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  factory ApiException.fromDio(DioException e) {
    final status = e.response?.statusCode;
    return switch ((e.type, status)) {
      (DioExceptionType.cancel, _) => const RequestCancelled(),
      (_, null) => NetworkUnavailable(e.message ?? 'No connection'),
      (_, 404) => const NotFound(),
      (_, final int s) when s >= 500 => ServerError(s),
      (_, final int s) => BadRequest(s, '${e.response?.data}'),
    };
  }

  final String message;

  @override
  String toString() => 'ApiException: $message';
}

final class NetworkUnavailable extends ApiException {
  const NetworkUnavailable(super.message);
}

final class NotFound extends ApiException {
  const NotFound() : super('Not found');
}

final class ServerError extends ApiException {
  ServerError(this.status) : super('Server error $status');
  final int status;
}

final class BadRequest extends ApiException {
  BadRequest(this.status, String body) : super('HTTP $status: $body');
  final int status;
}

/// A newer request superseded this one; callers should ignore it silently.
final class RequestCancelled extends ApiException {
  const RequestCancelled() : super('Cancelled');
}
