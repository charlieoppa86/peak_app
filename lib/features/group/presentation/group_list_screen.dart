import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/notification_bell_button.dart';
import '../data/group_mock_data.dart';

const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

/// 그룹 — 내가 만든 그룹 일정 / 초대받은 일정 구분 리스트 (docs/ia.md 그룹 IA).
class GroupListScreen extends StatelessWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mine = mockGroupSchedules.where((g) => g.isMine).toList()..sort((a, b) => a.date.compareTo(b.date));
    final invited = mockGroupSchedules.where((g) => !g.isMine).toList()..sort((a, b) => a.date.compareTo(b.date));

    return Scaffold(
      appBar: AppBar(title: const Text('그룹'), actions: const [NotificationBellButton()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionHeader(title: '내가 만든 일정', count: mine.length),
          const SizedBox(height: 8),
          if (mine.isEmpty)
            const _EmptyHint(text: '아직 만든 그룹 일정이 없어요.')
          else
            ...mine.map((g) => _GroupTile(group: g)),
          const SizedBox(height: 28),
          _SectionHeader(title: '초대받은 일정', count: invited.length),
          const SizedBox(height: 8),
          if (invited.isEmpty)
            const _EmptyHint(text: '받은 초대가 없어요.')
          else
            ...invited.map((g) => _GroupTile(group: g)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        Text(
          '$count건',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group});

  final GroupSchedule group;

  @override
  Widget build(BuildContext context) {
    final ratio = group.invitedCount == 0 ? 0.0 : group.confirmedCount / group.invitedCount;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        onTap: () => context.push('/group/${group.id}'),
        title: Text(group.courseName, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_dateLabel(group.date)} · ${group.time}'
                '${group.isMine ? '' : ' · 주최: ${group.organizerName}'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 5,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: const AlwaysStoppedAnimation(ScoreColors.fair),
                ),
              ),
              const SizedBox(height: 6),
              Text('참석 확정 ${group.confirmedCount} / 초대 ${group.invitedCount}명', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        isThreeLine: true,
      ),
    );
  }
}

String _dateLabel(DateTime date) => '${date.month}월 ${date.day}일 (${_weekdayLabels[date.weekday - 1]})';
