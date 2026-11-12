import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/theme.dart';
import 'l10n/app_localizations.dart';
import 'router.dart';
import 'state/providers.dart';

class BeautyCrmApp extends ConsumerWidget {
  const BeautyCrmApp({super.key, this.fontFamily = 'Inter'});
  final String? fontFamily;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final prefs = ref.watch(prefsProvider);
    return MaterialApp.router(
      onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light, fontFamily: fontFamily),
      darkTheme: buildTheme(Brightness.dark, fontFamily: fontFamily),
      themeMode: prefs.themeMode,
      locale: prefs.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates, // material + cupertino + widgets
      ],
      routerConfig: router,
      // Inter is ~7% wider than SF Pro used in the reference design; compensate while
      // still honouring the user's accessibility text scale.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * 0.93)),
          child: child!,
        );
      },
    );
  }
}
