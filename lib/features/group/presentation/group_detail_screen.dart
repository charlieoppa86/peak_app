import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_gate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/invite_share_sheet.dart';
import '../data/group_mock_data.dart';

const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

/// 그룹 일정 상세 — 참석자 목록 · 실시간 카운트 · 초대 공유 (US-005).
class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  GroupSchedule? get _group => mockGroupSchedules.where((g) => g.id == groupId).firstOrNull;

  Future<void> _openInvite(BuildContext context, GroupSchedule group) async {
    // 그룹 초대 공유는 로그인 게이트 적용 (US-002)
    if (!await ensureSignedIn(context,
        reason: '초대를 공유하려면 카카오 로그인이 필요해요.')) {
      return;
    }
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => InviteShareSheet(
        title: group.courseName,
        subtitle: '${_dateLabel(group.date)} · ${group.time}',
        link: 'https://peak.app/invite/${group.id}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    if (group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('그룹 일정 상세')),
        body: const Center(child: Text('그룹 일정을 찾을 수 없어요')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('그룹 일정 상세'),
        actions: [
          if (group.isMine)
            IconButton(
              tooltip: '일정 수정',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/group/${group.id}/edit'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(group.courseName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            '주최: ${group.organizerName}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _InfoRow(icon: Icons.calendar_today_outlined, label: '날짜', value: _dateLabel(group.date)),
                  const Divider(height: 24),
                  _InfoRow(icon: Icons.schedule_outlined, label: '출발 시간', value: group.time),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('참석 현황', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              Text(
                '참석 확정 ${group.confirmedCount} · 미응답 ${group.pendingCount} · 총 ${group.invitedCount}명',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < group.attendees.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 56),
                  _AttendeeTile(attendee: group.attendees[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => _openInvite(context, group),
            icon: const Icon(Icons.ios_share_outlined),
            label: const Text('초대 공유'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        SizedBox(
          width: 76,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _AttendeeTile extends StatelessWidget {
  const _AttendeeTile({required this.attendee});

  final Attendee attendee;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (attendee.status) {
      AttendeeStatus.confirmed => (Icons.check_circle, ScoreColors.good, '참석 확정'),
      AttendeeStatus.pending => (Icons.help_outline, ScoreColors.fair, '미응답'),
      AttendeeStatus.declined => (Icons.cancel_outlined, ScoreColors.poor, '불참'),
    };

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(attendee.name.substring(0, 1)),
      ),
      title: Text(attendee.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime date) => '${date.month}월 ${date.day}일 (${_weekdayLabels[date.weekday - 1]})';
