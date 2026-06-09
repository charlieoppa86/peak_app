import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/invite_share_sheet.dart';

const _referralCode = 'DONGHYUN29';
const _referralLink = 'https://peak.app/r/$_referralCode';

class _RewardEntry {
  const _RewardEntry({required this.label, required this.date, required this.status});

  final String label;
  final String date;
  final String status;
}

const _rewardHistory = [
  _RewardEntry(label: '박서연님 가입 · 첫 일정 등록 완료', date: '2026.06.02', status: '프로 1개월 지급'),
  _RewardEntry(label: '김지훈님 가입 · 첫 일정 등록 완료', date: '2026.05.21', status: '프로 1개월 지급'),
  _RewardEntry(label: '이도윤님 가입 완료', date: '2026.05.18', status: '첫 일정 등록 대기 중'),
];

/// 추천인 코드 — 링크 생성·공유, 초대 현황·보상 이력 (US-015).
class ReferralScreen extends StatelessWidget {
  const ReferralScreen({super.key});

  void _openShare(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => const InviteShareSheet(
        title: 'Peak 추천 링크',
        subtitle: '친구가 가입 후 첫 일정을 등록하면 프로 1개월이 지급돼요',
        link: _referralLink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('추천인 코드')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('내 추천 코드', style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
                  const SizedBox(height: 6),
                  Text(_referralCode, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    '친구에게 앱을 추천하고 추천받은 친구가 가입 후 첫 일정을 등록하면 나에게 프로 플랜 1개월이 자동 지급돼요.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _openShare(context),
                    icon: const Icon(Icons.ios_share_outlined),
                    label: const Text('추천 링크 공유'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text('초대 현황', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: _StatCard(label: '초대 발송', value: '12명', color: ScoreColors.fair)),
              SizedBox(width: 8),
              Expanded(child: _StatCard(label: '가입 완료', value: '5명', color: ScoreColors.good)),
              SizedBox(width: 8),
              Expanded(child: _StatCard(label: '보상 지급', value: '2개월', color: ScoreColors.good)),
            ],
          ),
          const SizedBox(height: 28),
          Text('보상 이력', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < _rewardHistory.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 16),
                  ListTile(
                    title: Text(_rewardHistory[i].label),
                    subtitle: Text(_rewardHistory[i].date),
                    trailing: Text(
                      _rewardHistory[i].status,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _rewardHistory[i].status.contains('지급') ? ScoreColors.good : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
