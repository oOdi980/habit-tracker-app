import 'package:habit_tracker/core/util/json.dart';
import 'package:habit_tracker/features/circles/circle_models.dart';

class AppUser {
  const AppUser({required this.id, required this.name, required this.email});

  factory AppUser.fromJson(Json json) => AppUser(
        id: asInt(json['id'], 'user.id'),
        name: asString(json['name'], 'user.name'),
        email: asString(json['email'], 'user.email'),
      );

  final int id;
  final String name;
  final String email;
}

/// Hasil login/daftar: token baru + pemilik token.
class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final AppUser user;
}

/// Hasil GET /api/auth/me: akun + semua sesi miliknya.
class MeResult {
  const MeResult({required this.user, required this.circles});

  final AppUser user;
  final List<Circle> circles;
}
