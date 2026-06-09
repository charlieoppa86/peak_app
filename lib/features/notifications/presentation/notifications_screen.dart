import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../data/notification_mock_data.dart';

/// 알림 — 날씨 악화 · 주간 TOP 3 요약 · 그룹 일정 변경 알림 인박스 (US-007, US-008).
/// 전역 벨 아이콘에서 진입하는 전체화면 push (탭이 아님 · docs/ia.md 참조).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  void _open(BuildContext context, WidgetRef ref, AppNotification notification) {
    ref.read(notificationsProvider.notifier).markRead(notification.id);
    switch (notification.type) {
      case NotificationType.weatherAlert:
        if (notification.scheduleId != null) {
          context.push('/home/schedule/${notification.scheduleId}/edit');
        }
      case NotificationType.weeklySummary:
        context.go('/home');
      case NotificationType.groupChange:
        if (notification.groupId != null) {
          context.push('/group/${notification.groupId}');
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final hasUnread = ref.watch(unreadCountProvider) > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: () => ref.read(notificationsProvider.notifier).markAllRead(),
              child: const Text('모두 읽음'),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? Center(
              child: Text(
                '받은 알림이 없어요',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationTile(
                  notification: notification,
                  onTap: () => _open(context, ref, notification),
                );
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (notification.type) {
      NotificationType.weatherAlert => (Icons.cloud_outlined, ScoreColors.poor),
      NotificationType.weeklySummary => (Icons.emoji_events_outlined, ScoreColors.good),
      NotificationType.groupChange => (Icons.groups_outlined, ScoreColors.fair),
    };

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.16),
        child: Icon(icon, color: color),
      ),
      title: Row(
        children: [
          if (!notification.read) ...[
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 6),
              decoration: const BoxDecoration(color: ScoreColors.fair, shape: BoxShape.circle),
            ),
          ],
          Expanded(
            child: Text(
              notification.title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: notification.read ? FontWeight.w500 : FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.body, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(
              _relativeLabel(notification.receivedAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
      isThreeLine: true,
    );
  }
}

String _relativeLabel(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  return '${diff.inDays}일 전';
}
