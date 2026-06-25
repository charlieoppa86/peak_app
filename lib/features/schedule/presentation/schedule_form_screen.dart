import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../home/data/home_mock_data.dart';

/// 일정 등록/수정 — 날짜·출발 시간·코스명 입력 (US-004, US-007 공유 화면).
/// 폼 필드는 로컬 UI 상태 → ConsumerStatefulWidget.
/// 저장 시에만 schedulesProvider.notifier를 write.
class ScheduleFormScreen extends ConsumerStatefulWidget {
  const ScheduleFormScreen({
    super.key,
    this.scheduleId,
    this.initialDate,
    this.initialType,
  });

  final String? scheduleId;

  /// 캘린더 CTA에서 진입 시 전달되는 초기값.
  final DateTime? initialDate;
  final ScheduleType? initialType;

  @override
  ConsumerState<ScheduleFormScreen> createState() => _ScheduleFormScreenState();
}

class _ScheduleFormScreenState extends ConsumerState<ScheduleFormScreen> {
  late final TextEditingController _courseController;
  late DateTime _date;
  late TimeOfDay _time;
  late ScheduleType _type;

  bool get _isEdit => widget.scheduleId != null;

  @override
  void initState() {
    super.initState();
    // ref은 ConsumerState에서 initState 시점부터 사용 가능
    final existing = widget.scheduleId == null
        ? null
        : ref
            .read(schedulesProvider)
            .where((s) => s.id == widget.scheduleId)
            .firstOrNull;

    _courseController = TextEditingController(text: existing?.courseName ?? '');
    _date = existing?.date ?? widget.initialDate ?? DateTime.now();
    _time = _parseTime(existing?.time) ?? const TimeOfDay(hour: 7, minute: 0);
    _type = existing?.type ?? widget.initialType ?? ScheduleType.solo;
  }

  @override
  void dispose() {
    _courseController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    final courseName = _courseController.text.trim();
    if (courseName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('코스명을 입력해주세요')),
      );
      return;
    }

    final timeLabel = _formatTime(_time);

    if (_isEdit) {
      final existing = ref
          .read(schedulesProvider)
          .where((s) => s.id == widget.scheduleId)
          .firstOrNull;
      if (existing == null) return;
      ref.read(schedulesProvider.notifier).update(
            existing.copyWith(
              date: _date,
              time: timeLabel,
              courseName: courseName,
              type: _type,
            ),
          );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일정을 수정했어요')),
      );
      context.pop();
    } else {
      final id = 'schedule_${DateTime.now().millisecondsSinceEpoch}';
      ref.read(schedulesProvider.notifier).add(
            RidingSchedule(
              id: id,
              date: _date,
              time: timeLabel,
              courseName: courseName,
              type: _type,
              status: ScheduleStatus.upcoming,
            ),
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일정을 등록했어요 · ${_type == ScheduleType.solo ? '혼자' : '같이'} 달리기')),
      );
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '일정 수정' : '일정 등록')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const _FieldLabel('날짜'),
          const SizedBox(height: 8),
          _PickerTile(
            icon: Icons.calendar_today_outlined,
            label: _dateLabel(_date),
            onTap: _pickDate,
          ),
          const SizedBox(height: 24),
          const _FieldLabel('출발 시간'),
          const SizedBox(height: 8),
          _PickerTile(
            icon: Icons.schedule_outlined,
            label: _time.format(context),
            onTap: _pickTime,
          ),
          const SizedBox(height: 24),
          const _FieldLabel('코스명'),
          const SizedBox(height: 8),
          TextField(
            controller: _courseController,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: '예: 한강 자유로 코스',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.route_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '즐겨찾기에서 선택',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final course in mockFavoriteCourses.take(5))
                ActionChip(
                  avatar: const Icon(Icons.star_outline, size: 16),
                  label: Text(course),
                  onPressed: () => setState(() => _courseController.text = course),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const _FieldLabel('함께하는 방식'),
          const SizedBox(height: 8),
          SegmentedButton<ScheduleType>(
            segments: const [
              ButtonSegment(
                value: ScheduleType.solo,
                label: Text('혼자 달리기'),
                icon: Icon(Icons.directions_bike_outlined),
              ),
              ButtonSegment(
                value: ScheduleType.group,
                label: Text('같이 달리기'),
                icon: Icon(Icons.groups_outlined),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _save,
            child: Text(_isEdit ? '수정 저장' : '일정 등록'),
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
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

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

const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

String _dateLabel(DateTime date) =>
    '${date.year}년 ${date.month}월 ${date.day}일 (${_weekdayLabels[date.weekday - 1]})';

String _formatTime(TimeOfDay t) {
  final isPm = t.hour >= 12;
  final h = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
  final m = t.minute.toString().padLeft(2, '0');
  return '${isPm ? '오후' : '오전'} $h:$m';
}

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
