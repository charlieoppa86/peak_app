import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/data/notification_mock_data.dart';

class PeakApp extends ConsumerStatefulWidget {
  const PeakApp({super.key});

  @override
  ConsumerState<PeakApp> createState() => _PeakAppState();
}

class _PeakAppState extends ConsumerState<PeakApp> {
  final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<RemoteMessage>? _foregroundSub;

  @override
  void initState() {
    super.initState();
    _foregroundSub = PushNotificationService.foregroundMessages.listen(_onForeground);
  }

  @override
  void dispose() {
    _foregroundSub?.cancel();
    super.dispose();
  }

  void _onForeground(RemoteMessage message) {
    final notification = AppNotification.fromRemoteMessage(message);

    // Riverpod 상태에 추가 → NotificationsScreen 즉시 반영
    ref.read(notificationsProvider.notifier).add(notification);

    // 인앱 배너 표시 (Android는 포그라운드에서 OS 알림 배너가 뜨지 않으므로 필수)
    _scaffoldKey.currentState?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification.title.isNotEmpty)
              Text(
                notification.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (notification.body.isNotEmpty)
              Text(
                notification.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        action: SnackBarAction(
          label: '보기',
          onPressed: () => appRouter.push('/notifications'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Peak',
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      scaffoldMessengerKey: _scaffoldKey,
      routerConfig: appRouter,
    );
  }
}
