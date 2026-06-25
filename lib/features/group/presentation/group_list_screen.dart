import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/home/data/home_mock_data.dart';
import '../../../shared/widgets/notification_bell_button.dart';
import '../data/group_mock_data.dart';

const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

/// 그룹 — 내가 만든 그룹 일정 / 초대받은 일정 구분 리스트 (docs/ia.md 그룹 IA).
/// '내가 만든 일정'은 schedulesProvider에서 type==group인 항목을 실시간으로 반영한다.
class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // schedulesProvider에서 그룹 타입 일정만 필터링 — 등록/삭제 즉시 반영
    final mine = ref
        .watch(schedulesProvider)
        .where((s) => s.type == ScheduleType.group)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // 초대받은 일정은 추후 서버 연동 (현재 항상 빈 리스트)
    final invited = mockGroupSchedules.where((g) => !g.isMine).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

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
            ...mine.map((s) => _MyGroupTile(schedule: s)),
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

/// schedulesProvider에서 파생된 그룹 타입 RidingSchedule 표시용 타일.
/// 탭 시 일정 상세(/home/schedule/:id)로 이동 — 초대·RSVP 기능 포함.
class _MyGroupTile extends StatelessWidget {
  const _MyGroupTile({required this.schedule});

  final RidingSchedule schedule;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        onTap: () => context.push('/home/schedule/${schedule.id}'),
        title: Text(schedule.courseName, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${_dateLabel(schedule.date)} · ${schedule.time}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
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
