import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:habit_tracker/core/api/api_client.dart';
import 'package:habit_tracker/core/config.dart';
import 'package:habit_tracker/core/providers.dart';
import 'package:habit_tracker/core/util/json.dart';
import 'package:habit_tracker/features/auth/auth_models.dart';
import 'package:habit_tracker/features/circles/circle_models.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<AuthResult> login({required String email, required String password}) async {
    final body = await _api.post('/api/auth/login', body: {
      'email': email,
      'password': password,
      'device_name': AppConfig.deviceName,
    });
    return _authResult(body);
  }

  /// [inviteCode] wajib untuk akun kedua dan seterusnya; akun pertama di server boleh kosong.
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    String? inviteCode,
  }) async {
    final body = await _api.post('/api/auth/register', body: {
      'name': name,
      'email': email,
      'password': password,
      'device_name': AppConfig.deviceName,
      if (inviteCode != null && inviteCode.trim().isNotEmpty) 'invite_code': inviteCode.trim(),
    });
    return _authResult(body);
  }

  Future<MeResult> me() async {
    final body = await _api.get('/api/auth/me');
    return MeResult(
      user: AppUser.fromJson(asJson(body['user'], 'user')),
      circles: asJsonList(body['circles'], 'circles').map(Circle.fromJson).toList(),
    );
  }

  Future<void> logout() async {
    await _api.post('/api/auth/logout');
  }

  AuthResult _authResult(Json body) => AuthResult(
        token: asString(body['token'], 'token'),
        user: AppUser.fromJson(asJson(body['user'], 'user')),
      );
}
