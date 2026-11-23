import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:habit_tracker/core/api/api_client.dart';
import 'package:habit_tracker/core/config.dart';
import 'package:habit_tracker/core/storage/session_store.dart';

/// Penyimpanan aman milik platform. Tes menimpa provider ini (atau sessionStoreProvider).
final keyValueStoreProvider = Provider<KeyValueStore>((ref) => SecureKeyValueStore());

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SessionStore(ref.watch(keyValueStoreProvider)),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    store: ref.watch(sessionStoreProvider),
  ),
);
