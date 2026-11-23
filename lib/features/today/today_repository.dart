import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:habit_tracker/core/api/api_client.dart';
import 'package:habit_tracker/core/providers.dart';
import 'package:habit_tracker/core/util/dates.dart';
import 'package:habit_tracker/core/util/json.dart';
import 'package:habit_tracker/features/today/today_models.dart';

final todayRepositoryProvider = Provider<TodayRepository>(
  (ref) => TodayRepository(ref.watch(apiClientProvider)),
);

class TodayRepository {
  TodayRepository(this._api);

  final ApiClient _api;

  Future<TodayBoard> board(int circleId) async {
    final body = await _api.get('/api/circles/$circleId/today');
    return TodayBoard.fromJson(body);
  }

  /// [tappedAt] = saat tombol ditekan di HP. Server hanya memakainya sebagai petunjuk bila selisihnya
  /// dengan jam server kecil (antrean offline di pergantian hari); selebihnya diabaikan.
  Future<CheckInResult> checkIn(int habitId, {required DateTime tappedAt}) async {
    final body = await _api.post(
      '/api/habits/$habitId/check-in',
      body: {'client_ts': utcIso8601(tappedAt)},
    );
    return CheckInResult.fromJson(asJson(body['check_in'], 'check_in'));
  }

  Future<CheckInResult> undoCheckIn(int habitId) async {
    final body = await _api.delete('/api/habits/$habitId/check-in');
    return CheckInResult.fromJson(asJson(body['check_in'], 'check_in'));
  }
}
