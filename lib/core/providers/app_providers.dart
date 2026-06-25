import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/home/data/home_mock_data.dart';
import '../../features/home/data/weather_recommendation_model.dart';
import '../../features/home/data/weather_recommendation_repository.dart';
import '../../features/notifications/data/notification_mock_data.dart';
import '../../shared/data/region_mock_data.dart';
import '../services/supabase_service.dart';

// ─── Supabase ─────────────────────────────────────────────────────────────────

/// Supabase 클라이언트. Supabase.initialize() 완료 후에만 유효.
final supabaseClientProvider = Provider<SupabaseClient>(
  (_) => SupabaseService.client,
);

/// 현재 로그인된 익명 유저 ID. 세션이 없으면 null.
final currentUserIdProvider = Provider<String?>(
  (_) => SupabaseService.currentUserId,
);

// ─── Schedules ───────────────────────────────────────────────────────────────

const _kSchedulesKey = 'riding_schedules_v1';

/// 사용자 라이딩 일정 전체. 변이(추가·수정·삭제·완료 토글)는 이 Notifier를 통해서만 일어난다.
/// SharedPreferences에 JSON으로 영속화 — 앱 재시작 후에도 유지된다.
class SchedulesNotifier extends Notifier<List<RidingSchedule>> {
  @override
  List<RidingSchedule> build() {
    // 동기 빌드 후 비동기로 저장된 데이터 로드
    _loadFromPrefs();
    return const [];
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_kSchedulesKey) ?? [];
    if (jsonList.isEmpty) return;
    state = List.unmodifiable(
      jsonList.map((s) => RidingSchedule.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList(),
    );
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kSchedulesKey,
      state.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }

  void toggleCompleted(String id) {
    state = List.unmodifiable([
      for (final s in state)
        if (s.id == id)
          s.copyWith(
            status: s.status == ScheduleStatus.completed
                ? ScheduleStatus.upcoming
                : ScheduleStatus.completed,
          )
        else
          s,
    ]);
    _persist();
  }

  void add(RidingSchedule schedule) {
    state = List.unmodifiable([...state, schedule]);
    _persist();
  }

  void update(RidingSchedule updated) {
    state = List.unmodifiable([
      for (final s in state) s.id == updated.id ? updated : s,
    ]);
    _persist();
  }

  void delete(String id) {
    state = List.unmodifiable(state.where((s) => s.id != id).toList());
    _persist();
  }
}

final schedulesProvider = NotifierProvider<SchedulesNotifier, List<RidingSchedule>>(
  SchedulesNotifier.new,
);

// ─── Derived schedule state ──────────────────────────────────────────────────

/// 예정 일정만 날짜 오름차순. 날짜 구조가 바뀔 때만 재계산.
final upcomingSchedulesProvider = Provider<List<RidingSchedule>>((ref) {
  return ref
      .watch(schedulesProvider)
      .where((s) => s.status == ScheduleStatus.upcoming)
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
});

/// 이번 달 완료 횟수. 횟수가 바뀔 때만 리빌드 유발.
final completedThisMonthProvider = Provider<int>((ref) {
  final month = DateTime.now().month;
  return ref
      .watch(schedulesProvider)
      .where((s) => s.status == ScheduleStatus.completed && s.date.month == month)
      .length;
});

// ─── Weather recommendation ──────────────────────────────────────────────────

final weatherRecommendationRepositoryProvider =
    Provider<WeatherRecommendationRepository>(
  (ref) => WeatherRecommendationRepository(ref.watch(supabaseClientProvider)),
);

/// 오늘 라이딩 추천 — Edge Function 호출. pull-to-refresh 시 ref.invalidate(이 provider).
/// selectedLocationProvider가 바뀌면 해당 지역 좌표로 자동 재조회한다.
class WeatherRecommendationNotifier
    extends AsyncNotifier<RidingRecommendation> {
  @override
  Future<RidingRecommendation> build() {
    // 위치가 바뀔 때마다 이 provider가 재빌드되어 새 좌표로 API를 재호출한다
    final location = ref.watch(selectedLocationProvider);
    final coord = mockRegionCoords[location.city]?[location.district];
    return ref.read(weatherRecommendationRepositoryProvider).fetch(
          lat: coord?.lat,
          lng: coord?.lng,
        );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() {
      final location = ref.read(selectedLocationProvider);
      final coord = mockRegionCoords[location.city]?[location.district];
      return ref.read(weatherRecommendationRepositoryProvider).fetch(
            lat: coord?.lat,
            lng: coord?.lng,
          );
    });
  }
}

final weatherRecommendationProvider = AsyncNotifierProvider<
    WeatherRecommendationNotifier, RidingRecommendation>(
  WeatherRecommendationNotifier.new,
);

// ─── Calendar / weather ──────────────────────────────────────────────────────

/// 캘린더에서 선택된 날짜 인덱스. null = 선택 없음.
class SelectedDayIndexNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  /// 같은 인덱스 재탭 시 해제, 다른 인덱스 탭 시 선택.
  void toggle(int index) => state = state == index ? null : index;
}

final selectedDayIndexProvider = NotifierProvider<SelectedDayIndexNotifier, int?>(
  SelectedDayIndexNotifier.new,
);

/// 2주 날씨 캘린더 데이터.
/// API forecast 배열이 있으면 해당 날짜를 실제 데이터로 채우고,
/// 커버되지 않는 날짜는 mock으로 fallback.
final weatherDaysProvider = Provider<List<WeatherDay>>((ref) {
  final recommendationAsync = ref.watch(weatherRecommendationProvider);

  return recommendationAsync.maybeWhen(
    data: (rec) {
      if (rec.forecast.isEmpty) return mockWeatherDays;

      final byDate = {for (final f in rec.forecast) f.date: f};
      final today = DateTime.now();

      return List.generate(14, (i) {
        final date = DateTime(today.year, today.month, today.day).add(Duration(days: i));
        final dateStr = '${date.year}'
            '${date.month.toString().padLeft(2, '0')}'
            '${date.day.toString().padLeft(2, '0')}';
        final f = byDate[dateStr];

        if (f != null) {
          final mock = i < mockWeatherDays.length ? mockWeatherDays[i] : null;
          return WeatherDay(
            date: date,
            score: f.score,
            temperature: f.temperature,
            precipitationChance: f.precipitationChance,
            windSpeed: f.windSpeed.round(),
            precipitation: mock?.precipitation ?? 0.0,
            dustLevel: mock?.dustLevel ?? DustLevel.moderate,
          );
        }
        return i < mockWeatherDays.length
            ? mockWeatherDays[i]
            : WeatherDay(
                date: date,
                score: 50,
                temperature: 20,
                precipitationChance: 20,
                windSpeed: 3,
                precipitation: 0.0,
                dustLevel: DustLevel.moderate,
              );
      });
    },
    orElse: () => mockWeatherDays,
  );
});

/// 현재 선택된 날의 WeatherDay. 선택이 없으면 null.
final selectedWeatherDayProvider = Provider<WeatherDay?>((ref) {
  final index = ref.watch(selectedDayIndexProvider);
  if (index == null) return null;
  final days = ref.watch(weatherDaysProvider);
  return index < days.length ? days[index] : null;
});

// ─── Group ───────────────────────────────────────────────────────────────────

/// 홈의 그룹 라이딩 현황 요약. 현재는 home_mock_data의 GroupReservation 사용.
final groupReservationsProvider = Provider<List<GroupReservation>>(
  (ref) => mockGroupReservations,
);

// ─── Location ────────────────────────────────────────────────────────────────

typedef SelectedLocation = ({String city, String district});

const _kLocationCityKey = 'location_city_v1';
const _kLocationDistrictKey = 'location_district_v1';

class LocationNotifier extends Notifier<SelectedLocation> {
  @override
  SelectedLocation build() {
    _loadFromPrefs();
    return (city: '서울특별시', district: '마포구');
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final city = prefs.getString(_kLocationCityKey);
    final district = prefs.getString(_kLocationDistrictKey);
    if (city != null && district != null) {
      state = (city: city, district: district);
    }
  }

  Future<void> update(String city, String district) async {
    state = (city: city, district: district);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocationCityKey, city);
    await prefs.setString(_kLocationDistrictKey, district);
  }
}

final selectedLocationProvider =
    NotifierProvider<LocationNotifier, SelectedLocation>(
  LocationNotifier.new,
);

// ─── Notifications ────────────────────────────────────────────────────────────

/// 알림 인박스. 초기값은 mock. FCM 수신 시 add()로 prepend, 탭 시 markRead().
class NotificationsNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() => List.unmodifiable(
        [...mockNotifications]
          ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt)),
      );

  /// FCM 포그라운드 수신 시 목록 맨 앞에 추가.
  void add(AppNotification notification) {
    state = List.unmodifiable([notification, ...state]);
  }

  /// 특정 알림 읽음 처리.
  void markRead(String id) {
    state = List.unmodifiable([
      for (final n in state) n.id == id ? n.copyWith(read: true) : n,
    ]);
  }

  /// 전체 읽음 처리.
  void markAllRead() {
    state = List.unmodifiable([
      for (final n in state) n.copyWith(read: true),
    ]);
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<AppNotification>>(
  NotificationsNotifier.new,
);

/// 읽지 않은 알림 수. 벨 배지에 사용.
final unreadCountProvider = Provider<int>(
  (ref) => ref.watch(notificationsProvider).where((n) => !n.read).length,
);
