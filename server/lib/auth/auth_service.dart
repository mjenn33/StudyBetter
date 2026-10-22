import 'dart:convert';
import 'dart:math';

import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:postgres/postgres.dart';

import '../config.dart';

class AuthService {
  AuthService(this.connection, this.config);
  final Connection connection;
  final Config config;

  String hashPassword(String password) =>
      BCrypt.hashpw(password, BCrypt.gensalt());
  bool verifyPassword(String password, String hash) =>
      BCrypt.checkpw(password, hash);
  String accessToken(String userId) => JWT({
    'sub': userId,
  }).sign(SecretKey(config.jwtSecret), expiresIn: const Duration(minutes: 15));
  String refreshToken() => base64Url.encode(
    List<int>.generate(48, (_) => Random.secure().nextInt(256)),
  );
  String hashToken(String token) => BCrypt.hashpw(token, BCrypt.gensalt());
  bool verifyRefresh(String token, String hash) => BCrypt.checkpw(token, hash);
  String? userIdFromAccess(String token) {
    try {
      return JWT.verify(token, SecretKey(config.jwtSecret)).payload['sub']
          as String?;
    } catch (_) {
      return null;
    }
  }
}
