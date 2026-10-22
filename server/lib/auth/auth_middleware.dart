import 'package:shelf/shelf.dart';

import 'auth_service.dart';

const currentUserIdKey = 'currentUserId';

String? authenticatedUserId(Request request, AuthService auth) {
  final value = request.headers['authorization'];
  if (value == null || !value.startsWith('Bearer ')) return null;
  return auth.userIdFromAccess(value.substring(7));
}

Middleware requireAuth(AuthService auth) =>
    (Handler inner) => (Request request) {
      final userId = authenticatedUserId(request, auth);
      return userId == null
          ? Response(401)
          : inner(request.change(context: {currentUserIdKey: userId}));
    };
