import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/cache.dart';
import 'core/token_store.dart';
import 'data/repository.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {}
  final tokens = SecureTokenStore();
  late final ProviderContainer container;
  final api = ApiClient(tokens, onSessionExpired: () => container.read(sessionProvider.notifier).expired());
  container = ProviderContainer(overrides: [repositoryProvider.overrideWithValue(CrmRepository(api, tokens, OfflineCache(prefs)))]);
  runApp(UncontrolledProviderScope(container: container, child: const BeautyCrmApp()));
}
