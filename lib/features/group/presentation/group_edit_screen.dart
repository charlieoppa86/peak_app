import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/group_mock_data.dart';

const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

/// 그룹 일정 수정 — 날짜 변경, 멤버 전원 재공지 푸시, 재응답 현황 (US-010).
class GroupEditScreen extends StatefulWidget {
  const GroupEditScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupEditScreen> createState() => _GroupEditScreenState();
}

class _GroupEditScreenState extends State<GroupEditScreen> {
  GroupSchedule? get _group => mockGroupSchedules.where((g) => g.id == widget.groupId).firstOrNull;

  late DateTime _date = _group?.date ?? DateTime.now();
  late TimeOfDay _time = _parseTime(_group?.time) ?? const TimeOfDay(hour: 7, minute: 0);

  /// 재공지 발송 후 전원이 재응답 대기 상태로 전환된 모습을 보여주기 위한 로컬 시뮬레이션.
  late List<AttendeeStatus> _statuses = [for (final a in _group?.attendees ?? const <Attendee>[]) a.status];
  bool _renotified = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _saveAndNotify() {
    final group = _group!;
    setState(() {
      _statuses = [for (var i = 0; i < group.attendees.length; i++) AttendeeStatus.pending];
      _renotified = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('변경된 일정을 멤버 ${group.attendees.length}명에게 알렸어요. 재응답을 기다리는 중이에요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    if (group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('그룹 일정 수정')),
        body: const Center(child: Text('그룹 일정을 찾을 수 없어요')),
      );
    }

    final confirmed = _statuses.where((s) => s == AttendeeStatus.confirmed).length;
    final pending = _statuses.where((s) => s == AttendeeStatus.pending).length;
    final declined = _statuses.where((s) => s == AttendeeStatus.declined).length;

    return Scaffold(
      appBar: AppBar(title: const Text('그룹 일정 수정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(group.courseName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          _FieldLabel('날짜'),
          const SizedBox(height: 8),
          _PickerTile(icon: Icons.calendar_today_outlined, label: _dateLabel(_date), onTap: _pickDate),
          const SizedBox(height: 20),
          _FieldLabel('출발 시간'),
          const SizedBox(height: 8),
          _PickerTile(icon: Icons.schedule_outlined, label: _time.format(context), onTap: _pickTime),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('재응답 현황', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              if (_renotified)
                const Chip(
                  avatar: Icon(Icons.notifications_active_outlined, size: 16),
                  label: Text('재공지 완료'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatusStat(label: '참석', count: confirmed, color: ScoreColors.good)),
              const SizedBox(width: 8),
              Expanded(child: _StatusStat(label: '미응답', count: pending, color: ScoreColors.fair)),
              const SizedBox(width: 8),
              Expanded(child: _StatusStat(label: '불참', count: declined, color: ScoreColors.poor)),
            ],
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _saveAndNotify,
            icon: const Icon(Icons.campaign_outlined),
            label: const Text('변경 사항 저장 · 멤버 전원에게 알리기'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 8),
          Text(
            '저장하면 참석을 수락한 멤버 전원에게 변경 알림이 발송되고, 재응답 대기 상태로 전환돼요.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600));
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
            const Spacer(),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _StatusStat extends StatelessWidget {
  const _StatusStat({required this.label, required this.count, required this.color});

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text('$count명', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime date) => '${date.year}년 ${date.month}월 ${date.day}일 (${_weekdayLabels[date.weekday - 1]})';

TimeOfDay? _parseTime(String? label) {
  if (label == null) return null;
  final isPm = label.contains('오후');
  final digits = RegExp(r'(\d+):(\d+)').firstMatch(label);
  if (digits == null) return null;
  var hour = int.parse(digits.group(1)!);
  final minute = int.parse(digits.group(2)!);
  if (isPm && hour != 12) hour += 12;
  if (!isPm && hour == 12) hour = 0;
  return TimeOfDay(hour: hour, minute: minute);
}
