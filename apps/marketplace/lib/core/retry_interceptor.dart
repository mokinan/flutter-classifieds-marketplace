import 'dart:async';

import 'package:dio/dio.dart';

/// Retries **GET** requests on connection errors and 5xx responses.
///
/// Only GETs are retried: they are safe to repeat. Writes go through
/// explicit, idempotent flows instead (see chat `clientId`).
class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio, {this.retries = 2, this.baseDelay = const Duration(milliseconds: 400)});

  final Dio _dio;
  final int retries;
  final Duration baseDelay;

  static const _attemptKey = 'retry_attempt';

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    final attempt = (request.extra[_attemptKey] as int?) ?? 0;
    final status = err.response?.statusCode;
    final transient =
        err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        (status != null && status >= 500);

    if (request.method != 'GET' || !transient || attempt >= retries || (request.cancelToken?.isCancelled ?? false)) {
      return handler.next(err);
    }

    await Future<void>.delayed(baseDelay * (1 << attempt));
    try {
      request.extra[_attemptKey] = attempt + 1;
      handler.resolve(await _dio.fetch<dynamic>(request));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
