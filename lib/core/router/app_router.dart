import 'package:go_router/go_router.dart';

import '../../features/group/presentation/group_detail_screen.dart';
import '../../features/home/data/home_mock_data.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/group/presentation/group_edit_screen.dart';
import '../../features/group/presentation/group_list_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/schedule/presentation/schedule_detail_screen.dart';
import '../../features/schedule/presentation/schedule_form_screen.dart';
import '../../features/schedule/presentation/schedule_rsvp_screen.dart';
import '../../features/settings/presentation/alert_settings_screen.dart';
import '../../features/settings/presentation/location_settings_screen.dart';
import '../../features/settings/presentation/plan_settings_screen.dart';
import '../../features/settings/presentation/profile_settings_screen.dart';
import '../../features/settings/presentation/referral_screen.dart';
import '../../features/settings/presentation/settings_home_screen.dart';
import '../../shared/widgets/app_shell.dart';

/// docs/ia.md "Flutter 라우팅 참고" 구조와 1:1 대응.
/// 일정은 홈 브랜치에 통합, 알림은 바텀 탭이 아닌 전역 push 라우트로 분리.
/// peak://home/schedule/:id/rsvp 커스텀 URL 스킴으로 들어오는 딥링크를 처리한다.
final appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) {
    // peak://home/schedule/:id/rsvp → /home/schedule/:id/rsvp
    final uri = state.uri;
    if (uri.scheme == 'peak') {
      final path = uri.host.isNotEmpty ? '/${uri.host}${uri.path}' : uri.path;
      final query = uri.query.isNotEmpty ? '?${uri.query}' : '';
      return '$path$query';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'schedule/new',
                  builder: (context, state) {
                    final extra = state.extra as Map<String, dynamic>?;
                    return ScheduleFormScreen(
                      initialDate: extra?['date'] as DateTime?,
                      initialType: extra?['type'] as ScheduleType?,
                    );
                  },
                ),
                GoRoute(
                  path: 'schedule/:id',
                  builder: (context, state) => ScheduleDetailScreen(scheduleId: state.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (context, state) => ScheduleFormScreen(scheduleId: state.pathParameters['id']),
                    ),
                    GoRoute(
                      path: 'rsvp',
                      builder: (context, state) => ScheduleRsvpScreen(
                        scheduleId: state.pathParameters['id']!,
                        course: state.uri.queryParameters['course'] ?? '',
                        date: state.uri.queryParameters['date'] ?? '',
                        time: state.uri.queryParameters['time'] ?? '',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/group',
              builder: (context, state) => const GroupListScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) => GroupDetailScreen(groupId: state.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (context, state) => GroupEditScreen(groupId: state.pathParameters['id']!),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsHomeScreen(),
              routes: [
                GoRoute(path: 'profile', builder: (context, state) => const ProfileSettingsScreen()),
                GoRoute(path: 'location', builder: (context, state) => const LocationSettingsScreen()),
                GoRoute(path: 'alerts', builder: (context, state) => const AlertSettingsScreen()),
                GoRoute(
                  path: 'plan',
                  builder: (context, state) => const PlanSettingsScreen(),
                  routes: [
                    GoRoute(path: 'referral', builder: (context, state) => const ReferralScreen()),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
