import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_better/data/remote/api_client.dart';

class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.respond);
  final Future<(int, Object)> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final (status, body) = await respond(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('attaches access token, rotates refresh once, retries once', () async {
    var refreshes = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    dio.httpClientAdapter = StubAdapter((options) async {
      if (options.path == '/auth/login') {
        return (200, {'accessToken': 'old', 'refreshToken': 'refresh'});
      }
      if (options.path == '/auth/refresh') {
        refreshes++;
        return (200, {'accessToken': 'new', 'refreshToken': 'rotated'});
      }
      return options.headers['Authorization'] == 'Bearer new'
          ? (200, {'id': 'user'})
          : (401, {'error': 'expired'});
    });
    final api = ApiClient('https://example.test/api/v1', dio: dio);
    await api.authenticate(email: 'a@b.com', password: 'password');
    expect(await api.request('GET', '/me'), {'id': 'user'});
    expect(refreshes, 1);
    await api.logout();
    expect(await api.isSignedIn, false);
    api.close();
  });
  test('does not retry a second 401 and isolates servers', () async {
    var refreshes = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    dio.httpClientAdapter = StubAdapter((options) async {
      if (options.path == '/auth/login') {
        return (200, {'accessToken': 'old', 'refreshToken': 'refresh'});
      }
      if (options.path == '/auth/refresh') {
        refreshes++;
        return (200, {'accessToken': 'new', 'refreshToken': 'rotated'});
      }
      return (401, {'error': 'expired'});
    });
    final api = ApiClient('https://example.test/api/v1', dio: dio);
    await api.authenticate(email: 'a@b.com', password: 'password');
    await expectLater(
      api.request('GET', '/me'),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.kind,
          'kind',
          ApiErrorKind.unauthorized,
        ),
      ),
    );
    expect(refreshes, 1);
    final other = ApiClient('https://other.test/api/v1');
    expect(await other.isSignedIn, false);
    other.close();
    api.close();
  });
  for (final status in [409, 422, 503]) {
    test('maps HTTP $status into typed error', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = StubAdapter(
        (_) async => (status, {'error': 'failure'}),
      );
      final api = ApiClient('https://example.test', dio: dio);
      final kind = {
        409: ApiErrorKind.conflict,
        422: ApiErrorKind.validation,
        503: ApiErrorKind.server,
      }[status];
      await expectLater(
        api.request('GET', '/quizzes'),
        throwsA(isA<ApiFailure>().having((e) => e.kind, 'kind', kind)),
      );
      api.close();
    });
  }
}
