import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 플랜 관리 — 무료 vs 프로 비교, 7일 무료 체험 CTA, 구독 상태 (US-013, US-014).
class PlanSettingsScreen extends StatelessWidget {
  const PlanSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('플랜 관리')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('무료 vs 프로 비교 · 7일 무료 체험 CTA · 구독 상태/갱신일 (구현 예정)'),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: const Text('추천인 코드'),
            subtitle: const Text('개인 추천 링크 생성·공유 · 보상 이력'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/plan/referral'),
          ),
        ],
      ),
    );
  }
}
