import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/services/admob_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/notification_bell_button.dart';
import '../data/home_mock_data.dart';
import '../data/weather_recommendation_model.dart';

const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ─── Screen ──────────────────────────────────────────────────────────────────

/// 홈 화면. 자체 상태 없음 — 모든 상태는 Riverpod provider에서 관리.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('홈'),
        actions: const [NotificationBellButton()],
      ),
      body: const Column(
        children: [
          Expanded(child: _HomeBody()),
          BannerAdWidget(),
        ],
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

/// pull-to-refresh: weatherRecommendationProvider만 갱신.
/// 각 섹션 위젯이 자신의 provider만 독립적으로 구독해 리빌드 범위를 최소화한다.
class _HomeBody extends ConsumerWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(weatherRecommendationProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: const [
          _TodayRecommendationCard(), // weatherRecommendationProvider 구독
          SizedBox(height: 24),
          _CalendarSectionHeader(),   // completedThisMonthProvider 구독
          SizedBox(height: 12),
          _TwoWeekCalendar(),         // weatherDaysProvider(정적) + 셀별 select
          SizedBox(height: 28),
          _ScheduleSectionHeader(),   // upcomingSchedulesProvider.select(length)
          SizedBox(height: 12),
          _ScheduleList(),            // upcomingSchedulesProvider → 타일별 select
          SizedBox(height: 28),
          _GroupSectionHeader(),      // 정적, 완전 const
          SizedBox(height: 12),
          _GroupReservationList(),    // groupReservationsProvider 구독
        ],
      ),
    );
  }
}

// ─── Calendar section ─────────────────────────────────────────────────────────

/// 이번 달 완료 횟수가 바뀔 때만 리빌드.
class _CalendarSectionHeader extends ConsumerWidget {
  const _CalendarSectionHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(completedThisMonthProvider);
    return _SectionHeader(
      title: '라이딩 스케쥴',
      trailing: '이번 달 완료 $count회',
    );
  }
}

/// 14개 날짜 격자. weatherDaysProvider는 정적이라 최초 1회만 빌드.
/// 선택 상태·일정 유무는 각 셀이 직접 구독하므로 이 위젯은 리빌드되지 않는다.
class _TwoWeekCalendar extends ConsumerWidget {
  const _TwoWeekCalendar();

  static const _cols = 7;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(weatherDaysProvider);
    final rows = days.length ~/ _cols;

    return Column(
      children: [
        for (var row = 0; row < rows; row++) ...[
          if (row > 0) const SizedBox(height: 10),
          Row(
            children: [
              for (var col = 0; col < _cols; col++) ...[
                if (col > 0) const SizedBox(width: 6),
                Expanded(
                  child: _CalendarDayCell(
                    key: ValueKey(row * _cols + col),
                    dayIndex: row * _cols + col,
                    day: days[row * _cols + col],
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// 셀별 독립 구독:
/// - schedulesProvider.select(첫 일정 타입) → 이 날의 일정 dot
/// 탭 시 Bottom Sheet로 날씨 상세 표시.
class _CalendarDayCell extends ConsumerWidget {
  const _CalendarDayCell({
    super.key,
    required this.dayIndex,
    required this.day,
  });

  final int dayIndex;
  final WeatherDay day;

  IconData get _weatherIcon {
    if (day.precipitationChance >= 60) return Icons.umbrella_outlined;
    if (day.precipitationChance >= 30) return Icons.cloud_outlined;
    if (day.score >= 70) return Icons.wb_sunny_outlined;
    return Icons.cloud_queue_outlined;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleType = ref.watch(
      schedulesProvider.select(
        (list) => list
            .where((s) => _isSameDay(s.date, day.date))
            .firstOrNull
            ?.type,
      ),
    );

    final color = ScoreColors.forScore(day.score);
    final isToday = _isSameDay(day.date, DateTime.now());

    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => _DayDetailSheet(day: day),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: isToday ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text(
              _weekdayLabels[day.date.weekday - 1],
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
            ),
            Text('${day.date.day}', style: Theme.of(context).textTheme.titleSmall),
            Icon(_weatherIcon, size: 16, color: color),
            SizedBox(
              height: 6,
              width: 6,
              child: scheduleType == null
                  ? null
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheduleType == ScheduleType.solo
                            ? ScoreColors.good
                            : ScoreColors.fair,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 달력 셀 탭 시 나타나는 Bottom Sheet — 날씨 상세 및 일정 CTA 포함.
class _DayDetailSheet extends StatelessWidget {
  const _DayDetailSheet({required this.day});
  final WeatherDay day;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: _DateDetailPanel(day: day),
    );
  }
}

/// 날짜 상세 패널. WeatherDay를 받아 렌더링만 — Riverpod 불필요.
class _DateDetailPanel extends StatelessWidget {
  const _DateDetailPanel({required this.day});

  final WeatherDay day;

  @override
  Widget build(BuildContext context) {
    final color = ScoreColors.forScore(day.score);
    final dustColor = _dustLevelColor(day.dustLevel);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${day.date.month}월 ${day.date.day}일 (${_weekdayLabels[day.date.weekday - 1]})',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${day.score}점',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _WeatherStat(
                icon: Icons.air_outlined,
                label: '바람세기',
                value: '${day.windSpeed}m/s',
              ),
              _WeatherStat(
                icon: Icons.blur_on_outlined,
                label: '미세먼지',
                value: day.dustLevel.label,
                valueColor: dustColor,
              ),
              _WeatherStat(
                icon: Icons.water_drop_outlined,
                label: '강수확률',
                value: '${day.precipitationChance}%',
              ),
              _WeatherStat(
                icon: Icons.grain_outlined,
                label: '강수량',
                value: '${day.precipitation}mm',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(
                    '/home/schedule/new',
                    extra: {'date': day.date, 'type': ScheduleType.solo},
                  ),
                  icon: const Icon(Icons.directions_bike_outlined, size: 16),
                  label: const Text('혼자 달리기'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.push(
                    '/home/schedule/new',
                    extra: {'date': day.date, 'type': ScheduleType.group},
                  ),
                  icon: const Icon(Icons.groups_outlined, size: 16),
                  label: const Text('같이 달리기'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeatherStat extends StatelessWidget {
  const _WeatherStat({
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: valueColor ?? Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(height: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontWeight: FontWeight.w600, color: valueColor),
        ),
      ],
    );
  }
}

Color _dustLevelColor(DustLevel level) => switch (level) {
      DustLevel.good => ScoreColors.good,
      DustLevel.moderate => ScoreColors.fair,
      DustLevel.unhealthy => const Color(0xFFFB923C),
      DustLevel.veryUnhealthy => ScoreColors.poor,
    };

// ─── Schedule section ─────────────────────────────────────────────────────────

/// 예정 일정 수만 구독 — 일정 데이터 내용 변경엔 반응 안 함.
class _ScheduleSectionHeader extends ConsumerWidget {
  const _ScheduleSectionHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(upcomingSchedulesProvider.select((list) => list.length));
    return _SectionHeader(title: '내 일정', trailing: '$count건 예정');
  }
}

/// 예정 일정 목록 구조(ID 목록)가 바뀔 때만 리빌드.
/// 각 타일은 자신의 ID에 해당하는 일정만 select로 구독 → 타일 간 독립.
class _ScheduleList extends ConsumerWidget {
  const _ScheduleList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(upcomingSchedulesProvider);

    if (schedules.isEmpty) {
      return const _EmptyHint(
        icon: Icons.directions_bike_outlined,
        text: '아직 등록된 일정이 없어요.',
        sub: '캘린더에서 날짜를 선택해 일정을 추가해보세요.',
      );
    }
    return Column(
      children: [
        for (final s in schedules)
          _ScheduleTile(key: ValueKey(s.id), scheduleId: s.id),
      ],
    );
  }
}

/// 이 일정의 레퍼런스가 바뀔 때만 리빌드 (다른 일정 변경 시 무반응).
class _ScheduleTile extends ConsumerWidget {
  const _ScheduleTile({super.key, required this.scheduleId});

  final String scheduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(
      upcomingSchedulesProvider.select(
        (list) => list.firstWhere((s) => s.id == scheduleId),
      ),
    );

    final isGroup = schedule.type == ScheduleType.group;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/home/schedule/${schedule.id}'),
        leading: CircleAvatar(
          backgroundColor:
              (isGroup ? ScoreColors.fair : ScoreColors.good).withValues(alpha: 0.18),
          child: Icon(
            isGroup ? Icons.groups_outlined : Icons.directions_bike_outlined,
            color: isGroup ? ScoreColors.fair : ScoreColors.good,
          ),
        ),
        title: Text(schedule.courseName),
        subtitle: Text(
          '${_dateLabel(schedule.date)} · ${schedule.time} · ${isGroup ? '같이' : '혼자'}',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

// ─── Group section ────────────────────────────────────────────────────────────

class _GroupSectionHeader extends StatelessWidget {
  const _GroupSectionHeader();

  @override
  Widget build(BuildContext context) {
    return const _SectionHeader(title: '그룹 라이딩 현황');
  }
}

class _GroupReservationList extends ConsumerWidget {
  const _GroupReservationList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservations = ref.watch(groupReservationsProvider);

    if (reservations.isEmpty) {
      return const _EmptyHint(
        icon: Icons.groups_outlined,
        text: '참여 중인 그룹 라이딩이 없어요.',
        sub: '같이 달리기로 일정을 만들거나 초대를 기다려보세요.',
      );
    }
    return Column(
      children: [
        for (final g in reservations) _GroupReservationTile(reservation: g),
      ],
    );
  }
}

class _GroupReservationTile extends StatelessWidget {
  const _GroupReservationTile({required this.reservation});

  final GroupReservation reservation;

  @override
  Widget build(BuildContext context) {
    final ratio = reservation.invitedCount == 0
        ? 0.0
        : reservation.confirmedCount / reservation.invitedCount;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reservation.title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              _dateLabel(reservation.date),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '참석 확정 ${reservation.confirmedCount} / 초대 ${reservation.invitedCount}명',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared primitives ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text, this.sub});

  final IconData icon;
  final String text;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(
              sub!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Today recommendation card ───────────────────────────────────────────────

/// 오늘 라이딩 추천 카드. weatherRecommendationProvider의 상태(loading/error/data)를 표시.
class _TodayRecommendationCard extends ConsumerWidget {
  const _TodayRecommendationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(weatherRecommendationProvider);
    return state.when(
      loading: () => const _RecommendationSkeleton(),
      error: (err, _) => _RecommendationError(error: err),
      data: (rec) => _RecommendationContent(recommendation: rec),
    );
  }
}

class _RecommendationSkeleton extends StatelessWidget {
  const _RecommendationSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _RecommendationError extends ConsumerWidget {
  const _RecommendationError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msg = error is WeatherFetchException
        ? '[${(error as WeatherFetchException).code}] ${(error as WeatherFetchException).message}'
        : error.toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined,
              color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(weatherRecommendationProvider.notifier).refresh(),
            child: const Text('재시도'),
          ),
        ],
      ),
    );
  }
}

class _RecommendationContent extends ConsumerWidget {
  const _RecommendationContent({required this.recommendation});
  final RidingRecommendation recommendation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (badgeColor, badgeText) = switch (recommendation.recommendation) {
      RecommendationLevel.good => (ScoreColors.good, '추천'),
      RecommendationLevel.normal => (ScoreColors.fair, '보통'),
      RecommendationLevel.bad => (ScoreColors.poor, '비추천'),
    };

    final location = ref.watch(selectedLocationProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오늘의 날씨',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${location.city} ${location.district}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badgeText,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: badgeColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_outlined,
                          size: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(
                        recommendation.recommendedTimeSlot,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _InfoChip(icon: Icons.wb_sunny_outlined, label: recommendation.weather),
              _InfoChip(icon: Icons.thermostat_outlined, label: recommendation.temperature),
              _InfoChip(icon: Icons.air_outlined, label: recommendation.wind),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            recommendation.reason,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime date) {
  final today = DateTime.now();
  final diff = DateTime(date.year, date.month, date.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
  final base = '${date.month}월 ${date.day}일 (${_weekdayLabels[date.weekday - 1]})';
  if (diff == 0) return '오늘 · $base';
  if (diff == 1) return '내일 · $base';
  if (diff == -1) return '어제 · $base';
  return base;
}
