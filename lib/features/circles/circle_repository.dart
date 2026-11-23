import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:habit_tracker/core/api/api_client.dart';
import 'package:habit_tracker/core/providers.dart';
import 'package:habit_tracker/core/util/json.dart';
import 'package:habit_tracker/features/circles/circle_models.dart';

final circleRepositoryProvider = Provider<CircleRepository>(
  (ref) => CircleRepository(ref.watch(apiClientProvider)),
);

class CircleRepository {
  CircleRepository(this._api);

  final ApiClient _api;

  /// Zona waktu dikunci server setelah sesi dibuat (menentukan batas hari dan minggu).
  Future<Circle> create({required String name, required String timezone}) async {
    final body = await _api.post('/api/circles', body: {'name': name, 'timezone': timezone});
    return Circle.fromJson(asJson(body['circle'], 'circle'));
  }

  Future<Circle> join(String code) async {
    final body = await _api.post('/api/circles/join', body: {'code': code.trim()});
    return Circle.fromJson(asJson(body['circle'], 'circle'));
  }

  /// Membuat kode baru; kode lama yang masih aktif langsung hangus di server.
  Future<CircleInvite> createInvite(int circleId) async {
    final body = await _api.post('/api/circles/$circleId/invites');
    return CircleInvite.fromJson(body);
  }
}
