import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/providers.dart';

final serverUrlProvider = FutureProvider<String>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .read('serverUrl', 'http://localhost:8080/api/v1'),
);
final apiClientProvider = FutureProvider<ApiClient>((ref) async {
  final url = await ref.watch(serverUrlProvider.future);
  final client = ApiClient(url);
  ref.onDispose(client.close);
  return client;
});

enum ApiErrorKind { offline, validation, conflict, unauthorized, server }

class ApiFailure implements Exception {
  const ApiFailure(this.kind, this.message, [this.details]);
  final ApiErrorKind kind;
  final String message;
  final Object? details;
  @override
  String toString() => message;
}

/// One secure record per server prevents credentials crossing server settings.
class ApiClient {
  ApiClient(String baseUrl, {Dio? dio, FlutterSecureStorage? storage})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
            ),
          ),
      _storage = storage ?? const FlutterSecureStorage(),
      _key = 'studybetter.tokens.${Uri.encodeComponent(baseUrl)}' {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final tokens = options.extra['authenticated'] == false
                ? null
                : await _tokens();
            if (tokens != null) {
              options.headers['Authorization'] =
                  'Bearer ${tokens['accessToken']}';
            }
            handler.next(options);
          } catch (error) {
            handler.reject(DioException(requestOptions: options, error: error));
          }
        },
        onError: (error, handler) async {
          final options = error.requestOptions;
          if (error.response?.statusCode != 401 ||
              options.extra['authenticated'] == false ||
              options.extra['retried'] == true ||
              options.headers['Authorization'] == null) {
            handler.next(error);
            return;
          }
          try {
            final current = await _tokens();
            if (current == null) {
              handler.next(error);
              return;
            }
            // A delayed 401 may arrive after another request refreshed already.
            if (options.headers['Authorization'] ==
                'Bearer ${current['accessToken']}') {
              await (_refreshing ??= _refresh().whenComplete(
                () => _refreshing = null,
              ));
            }
            options.extra['retried'] = true;
            handler.resolve(await _dio.fetch<Object?>(options));
          } on DioException catch (retryError) {
            handler.next(retryError);
          } catch (refreshError) {
            handler.reject(
              DioException(requestOptions: options, error: refreshError),
            );
          }
        },
      ),
    );
  }
  final Dio _dio;
  final FlutterSecureStorage _storage;
  final String _key;
  Future<void>? _refreshing;

  Future<Map<String, dynamic>?> _tokens() async {
    final value = await _storage.read(key: _key);
    return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
  }

  Future<bool> get isSignedIn async => await _tokens() != null;
  Future<void> logout() => _storage.delete(key: _key);
  void close() => _dio.close();

  Future<void> authenticate({
    required String email,
    required String password,
    String? username,
  }) async {
    final data = await request(
      'POST',
      '/auth/${username == null ? 'login' : 'register'}',
      data: {'email': email, 'password': password, 'username': ?username},
      authenticated: false,
    );
    await _storage.write(key: _key, value: jsonEncode(data));
  }

  Future<Object?> request(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    int? version,
    bool authenticated = true,
  }) async {
    try {
      return (await _dio.request<Object?>(
        path,
        data: data,
        queryParameters: query,
        options: Options(
          method: method,
          extra: {'authenticated': authenticated},
          headers: {if (version != null) 'If-Match': '$version'},
        ),
      )).data;
    } on DioException catch (error) {
      if (error.error case final ApiFailure failure) throw failure;
      final status = error.response?.statusCode;
      final kind = switch (status) {
        401 || 403 => ApiErrorKind.unauthorized,
        409 => ApiErrorKind.conflict,
        400 || 422 => ApiErrorKind.validation,
        null => ApiErrorKind.offline,
        _ => ApiErrorKind.server,
      };
      throw ApiFailure(kind, switch (kind) {
        ApiErrorKind.offline =>
          'Cannot reach the server. Your local library is available offline.',
        ApiErrorKind.unauthorized => 'Please sign in to continue.',
        ApiErrorKind.conflict => 'The server has a newer version.',
        ApiErrorKind.validation => 'Please check the submitted information.',
        ApiErrorKind.server =>
          'The server could not complete this request. Try again later.',
      }, error.response?.data);
    }
  }

  Future<void> _refresh() async {
    final tokens = await _tokens();
    try {
      final data = await request(
        'POST',
        '/auth/refresh',
        data: {'refreshToken': tokens?['refreshToken']},
        authenticated: false,
      );
      await _storage.write(key: _key, value: jsonEncode(data));
    } on ApiFailure catch (error) {
      if (error.kind == ApiErrorKind.unauthorized) await logout();
      rethrow;
    }
  }
}
