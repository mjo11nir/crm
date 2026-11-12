import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'features/appointments/appointment_detail_screen.dart';
import 'features/appointments/appointment_form_screen.dart';
import 'features/auth/auth_screens.dart';
import 'features/chats/chats_screens.dart';
import 'features/clients/clients_screens.dart';
import 'features/free_slots/free_slots_screen.dart';
import 'features/home/home_screen.dart';
import 'features/more/more_screen.dart';
import 'features/schedule/schedule_screen.dart';
import 'features/services/services_screens.dart';
import 'features/settings/settings_screens.dart';
import 'state/providers.dart';
import 'ui/shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  Page<void> modal(Widget child) => MaterialPage(fullscreenDialog: true, child: child);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final s = ref.read(sessionProvider);
      if (s.isLoading) return state.matchedLocation == '/splash' ? null : '/splash';
      final loggedIn = s.value != null;
      final authRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      if (!loggedIn) return authRoute ? null : '/login';
      if (authRoute || state.matchedLocation == '/splash') return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/schedule', builder: (_, _) => const ScheduleScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chats',
                builder: (_, _) => const ChatsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, s) => ChatScreen(conversationId: s.pathParameters['id']!, title: s.uri.queryParameters['title'] ?? ''),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (_, _) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: 'clients',
                    builder: (_, _) => const ClientsScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (_, s) => ClientProfileScreen(clientId: s.pathParameters['id']!),
                      ),
                    ],
                  ),
                  GoRoute(path: 'services', builder: (_, _) => const ServicesScreen()),
                  GoRoute(path: 'work-schedule', builder: (_, _) => const WorkScheduleScreen()),
                  GoRoute(path: 'online-booking', builder: (_, _) => const OnlineBookingSettingsScreen()),
                  GoRoute(path: 'waitlist', builder: (_, _) => const WaitlistScreen()),
                  GoRoute(path: 'web-page', builder: (_, _) => const WebPageScreen()),
                  GoRoute(path: 'client-notifications', builder: (_, _) => const ClientNotificationsScreen()),
                  GoRoute(path: 'alerts', builder: (_, _) => const AlertsScreen()),
                  GoRoute(path: 'calendar-sync', builder: (_, _) => const CalendarSyncScreen()),
                  GoRoute(path: 'appearance', builder: (_, _) => const AppearanceScreen()),
                  GoRoute(path: 'language', builder: (_, _) => const LanguageScreen()),
                  GoRoute(path: 'subscription', builder: (_, _) => const SubscriptionScreen()),
                  GoRoute(path: 'statistics', builder: (_, _) => const StatisticsScreen()),
                  GoRoute(path: 'account', builder: (_, _) => const AccountScreen()),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/appointment/new',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => modal(
          AppointmentFormScreen(
            initialDate: s.uri.queryParameters['date'],
            initialStart: s.uri.queryParameters['start'],
            clientId: s.uri.queryParameters['clientId'],
          ),
        ),
      ),
      GoRoute(
        path: '/appointment/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => AppointmentDetailScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/appointment/:id/edit',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => modal(AppointmentFormScreen(editId: s.pathParameters['id'])),
      ),
      GoRoute(path: '/free-slots', parentNavigatorKey: _rootKey, pageBuilder: (_, _) => modal(const FreeSlotsScreen())),
      GoRoute(
        path: '/client-form',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => modal(ClientFormScreen(clientId: s.uri.queryParameters['id'])),
      ),
      GoRoute(
        path: '/service-form',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => modal(ServiceFormScreen(serviceId: s.uri.queryParameters['id'])),
      ),
      GoRoute(path: '/notifications', parentNavigatorKey: _rootKey, builder: (_, _) => const ClientNotificationsScreen()),
    ],
  );
});
