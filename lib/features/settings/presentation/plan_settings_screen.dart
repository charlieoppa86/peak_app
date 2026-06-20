import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 플랜 관리 — 현재 전면 무료, 추천인 코드로 친구 초대만 제공.
class PlanSettingsScreen extends StatelessWidget {
  const PlanSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('플랜 관리')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('무료 플랜 이용 중', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('모든 기능을 무료로 사용할 수 있어요', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: const Text('추천인 코드'),
            subtitle: const Text('내 코드를 공유하고 친구를 초대해요'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/plan/referral'),
          ),
        ],
      ),
    );
  }
}
