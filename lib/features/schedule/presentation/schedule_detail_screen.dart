import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/invite_share_sheet.dart';
import '../../home/data/home_mock_data.dart';

/// 일정 상세 — 정보 표시, 완료 체크, 초대하기 진입, 수정/삭제 (US-005, US-009).
/// schedulesProvider.select로 이 일정만 구독 → 다른 일정 변경 시 리빌드 없음.
class ScheduleDetailScreen extends ConsumerWidget {
  const ScheduleDetailScreen({super.key, required this.scheduleId});

  final String scheduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(
      schedulesProvider.select(
        (list) => list.where((s) => s.id == scheduleId).firstOrNull,
      ),
    );

    if (schedule == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('일정 상세')),
        body: const Center(child: Text('일정을 찾을 수 없어요')),
      );
    }

    return _ScheduleDetailView(schedule: schedule);
  }
}

/// 실제 UI. schedule 객체가 바뀔 때만 리빌드.
class _ScheduleDetailView extends ConsumerWidget {
  const _ScheduleDetailView({required this.schedule});

  final RidingSchedule schedule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isToday = _isSameDay(schedule.date, DateTime.now());

    // 오늘 일정은 API 실제 데이터, 그 외는 mock 데이터 사용
    final todayRec = isToday
        ? ref.watch(weatherRecommendationProvider).asData?.value
        : null;
    final mockWeather = isToday
        ? null
        : ref.watch(
            weatherDaysProvider.select(
              (days) => days.where((d) => _isSameDay(d.date, schedule.date)).firstOrNull,
            ),
          );

    final isGroup = schedule.type == ScheduleType.group;
    final isCompleted = schedule.status == ScheduleStatus.completed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('일정 상세'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                context.push('/home/schedule/${schedule.id}/edit');
              }
              if (value == 'delete') _confirmDelete(context, ref);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('수정')),
              PopupMenuItem(value: 'delete', child: Text('삭제')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    (isGroup ? ScoreColors.fair : ScoreColors.good).withValues(alpha: 0.18),
                child: Icon(
                  isGroup ? Icons.groups_outlined : Icons.directions_bike_outlined,
                  color: isGroup ? ScoreColors.fair : ScoreColors.good,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.courseName,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isGroup ? '같이 달리기' : '혼자 달리기',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (isCompleted)
                const Chip(
                  avatar: Icon(Icons.check_circle, size: 16, color: ScoreColors.good),
                  label: Text('완료'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: '날짜',
                    value: _dateLabel(schedule.date),
                  ),
                  const Divider(height: 24),
                  _InfoRow(
                    icon: Icons.schedule_outlined,
                    label: '출발 시간',
                    value: schedule.time,
                  ),
                  if (todayRec != null) ...[
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.thermostat_outlined,
                      label: '라이딩 점수',
                      value:
                          '${todayRec.score}점 · ${todayRec.temperature} · ${todayRec.recommendation.label}',
                      valueColor: ScoreColors.forScore(todayRec.score),
                    ),
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.air_outlined,
                      label: '날씨 정보',
                      value: '${todayRec.weather} · ${todayRec.wind}',
                    ),
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.schedule_outlined,
                      label: '추천 시간',
                      value: todayRec.recommendedTimeSlot,
                    ),
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.info_outline,
                      label: '한줄 요약',
                      value: todayRec.reason,
                    ),
                  ] else if (mockWeather != null) ...[
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.thermostat_outlined,
                      label: '라이딩 점수',
                      value:
                          '${mockWeather.score}점 · ${mockWeather.temperature}℃ · 강수 ${mockWeather.precipitationChance}% · 풍속 ${mockWeather.windSpeed}m/s',
                      valueColor: ScoreColors.forScore(mockWeather.score),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () {
              // 현재 상태 기준으로 스낵바 메시지 결정 후 토글
              final msg = isCompleted ? '완료 표시를 취소했어요' : '라이딩 완료로 표시했어요 🎉';
              ref.read(schedulesProvider.notifier).toggleCompleted(schedule.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(msg)),
              );
            },
            icon: Icon(isCompleted ? Icons.check_circle : Icons.check_circle_outline),
            label: Text(isCompleted ? '완료 취소하기' : '라이딩 완료 체크'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: isCompleted ? ScoreColors.good : null,
              side: isCompleted ? const BorderSide(color: ScoreColors.good) : null,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => showModalBottomSheet(
              context: context,
              showDragHandle: true,
              builder: (context) => InviteShareSheet(
                title: schedule.courseName,
                subtitle: '${_dateLabel(schedule.date)} · ${schedule.time}',
                link: _buildInviteLink(schedule),
                weatherScore: todayRec?.score ?? mockWeather?.score,
              ),
            ),
            icon: const Icon(Icons.ios_share_outlined),
            label: const Text('초대하기'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 28),
          _RsvpList(scheduleId: schedule.id),
        ],
      ),
    );
  }

  String _buildInviteLink(RidingSchedule schedule) {
    const base = 'https://aulhqkkumomdbryxyskr.supabase.co/functions/v1/invite';
    final id = schedule.id;
    final course = Uri.encodeComponent(schedule.courseName);
    final date = Uri.encodeComponent(_dateLabel(schedule.date));
    final time = Uri.encodeComponent(schedule.time);
    return '$base/$id?course=$course&date=$date&time=$time';
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일정을 삭제할까요?'),
        content: const Text('삭제하면 되돌릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      ref.read(schedulesProvider.notifier).delete(schedule.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일정을 삭제했어요')),
      );
      context.go('/home');
    }
  }
}

// ─── RSVP 참석자 목록 ────────────────────────────────────────────────────────

class _RsvpList extends StatefulWidget {
  const _RsvpList({required this.scheduleId});
  final String scheduleId;

  @override
  State<_RsvpList> createState() => _RsvpListState();
}

class _RsvpListState extends State<_RsvpList> {
  List<Map<String, dynamic>> _rsvps = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Supabase.instance.client
          .from('schedule_rsvps')
          .select('name, status, created_at')
          .eq('riding_schedule_id', widget.scheduleId)
          .order('created_at');
      if (mounted) setState(() { _rsvps = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('참석 응답', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            if (!_loading)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
                child: Text('${_rsvps.length}명', style: text.labelSmall),
              ),
            const Spacer(),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh_outlined, size: 18), visualDensity: VisualDensity.compact),
          ],
        ),
        const SizedBox(height: 10),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_rsvps.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
            child: Text('아직 참석 응답이 없어요.', style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant), textAlign: TextAlign.center),
          )
        else
          Container(
            decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: _rsvps.asMap().entries.map((e) {
                final i = e.key;
                final r = e.value;
                final status = r['status'] as String;
                final (icon, color, label) = switch (status) {
                  'attending' => (Icons.check_circle_outline, Colors.green, '참석'),
                  'maybe'     => (Icons.help_outline, Colors.orange, '미정'),
                  _           => (Icons.cancel_outlined, Colors.red, '불참'),
                };
                return Column(
                  children: [
                    if (i > 0) Divider(height: 1, indent: 16, endIndent: 16, color: colors.outline.withValues(alpha: 0.3)),
                    ListTile(
                      dense: true,
                      leading: Icon(icon, color: color, size: 20),
                      title: Text(r['name'] as String, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      trailing: Text(label, style: text.bodySmall?.copyWith(color: color)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: valueColor,
                  fontWeight: valueColor != null ? FontWeight.w700 : null,
                ),
          ),
        ),
      ],
    );
  }
}

const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dateLabel(DateTime date) =>
    '${date.month}월 ${date.day}일 (${_weekdayLabels[date.weekday - 1]})';
