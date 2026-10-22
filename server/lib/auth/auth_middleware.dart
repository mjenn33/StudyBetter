import 'package:shelf/shelf.dart';

import 'auth_service.dart';

const currentUserIdKey = 'currentUserId';

Middleware requireAuth(AuthService auth) =>
    (Handler inner) => (Request request) {
      final value = request.headers['authorization'];
      if (value == null || !value.startsWith('Bearer ')) return Response(401);
      final userId = auth.userIdFromAccess(value.substring(7));
      return userId == null
          ? Response(401)
          : inner(request.change(context: {currentUserIdKey: userId}));
    };
