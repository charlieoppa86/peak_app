import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/notification_bell_button.dart';

/// 설정 홈 — 프로필 · 지역 · 알림 · 플랜 관리 메뉴 리스트.
class SettingsHomeScreen extends StatelessWidget {
  const SettingsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = const [
      _SettingsItem('프로필', '이름/닉네임 · 선호 운동 요일', '/settings/profile', Icons.person_outline),
      _SettingsItem('지역', '시/구 단위 지역 변경', '/settings/location', Icons.place_outlined),
      _SettingsItem('알림', '주간 요약 · 날씨 악화 트리거 기준', '/settings/alerts', Icons.notifications_outlined),
      _SettingsItem('플랜 관리', '무료 이용 중 · 추천인 코드', '/settings/plan', Icons.workspace_premium_outlined),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('설정'), actions: const [NotificationBellButton()]),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            leading: Icon(item.icon),
            title: Text(item.title),
            subtitle: Text(item.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(item.route),
          );
        },
      ),
    );
  }
}

class _SettingsItem {
  const _SettingsItem(this.title, this.subtitle, this.route, this.icon);

  final String title;
  final String subtitle;
  final String route;
  final IconData icon;
}
