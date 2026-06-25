/// 홈 화면 목 데이터. 추후 실제 날씨/일정 API 연동 시 이 파일만 교체하면 된다.
library;

enum ScheduleType { solo, group }

enum ScheduleStatus { upcoming, completed }

enum DustLevel {
  good,
  moderate,
  unhealthy,
  veryUnhealthy;

  String get label => switch (this) {
        DustLevel.good => '좋음',
        DustLevel.moderate => '보통',
        DustLevel.unhealthy => '나쁨',
        DustLevel.veryUnhealthy => '매우나쁨',
      };
}

class WeatherDay {
  const WeatherDay({
    required this.date,
    required this.score,
    required this.temperature,
    required this.precipitationChance,
    required this.windSpeed,
    required this.precipitation,
    required this.dustLevel,
  });

  final DateTime date;
  final int score;
  final int temperature;
  final int precipitationChance;
  final int windSpeed;
  final double precipitation; // mm
  final DustLevel dustLevel;
}

class RidingSchedule {
  const RidingSchedule({
    required this.id,
    required this.date,
    required this.time,
    required this.courseName,
    required this.type,
    required this.status,
  });

  final String id;
  final DateTime date;
  final String time;
  final String courseName;
  final ScheduleType type;
  final ScheduleStatus status;

  RidingSchedule copyWith({
    String? id,
    DateTime? date,
    String? time,
    String? courseName,
    ScheduleType? type,
    ScheduleStatus? status,
  }) {
    return RidingSchedule(
      id: id ?? this.id,
      date: date ?? this.date,
      time: time ?? this.time,
      courseName: courseName ?? this.courseName,
      type: type ?? this.type,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'time': time,
        'courseName': courseName,
        'type': type.name,
        'status': status.name,
      };

  factory RidingSchedule.fromJson(Map<String, dynamic> json) => RidingSchedule(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        time: json['time'] as String,
        courseName: json['courseName'] as String,
        type: ScheduleType.values.byName(json['type'] as String),
        status: ScheduleStatus.values.byName(json['status'] as String),
      );
}

class GroupReservation {
  const GroupReservation({
    required this.title,
    required this.date,
    required this.confirmedCount,
    required this.invitedCount,
  });

  final String title;
  final DateTime date;
  final int confirmedCount;
  final int invitedCount;
}

DateTime _today = DateTime.now();
DateTime _d(int dayOffset) => DateTime(_today.year, _today.month, _today.day).add(Duration(days: dayOffset));

const _scores = [82, 88, 64, 45, 91, 70, 55, 38, 76, 84, 92, 60, 49, 73];

const _precipitations = [0.0, 0.0, 1.5, 5.0, 0.0, 0.5, 2.0, 8.0, 0.0, 0.0, 0.0, 1.0, 3.5, 0.0];

const _dustLevels = [
  DustLevel.good, DustLevel.good, DustLevel.moderate, DustLevel.unhealthy,
  DustLevel.good, DustLevel.moderate, DustLevel.unhealthy, DustLevel.veryUnhealthy,
  DustLevel.moderate, DustLevel.good, DustLevel.good, DustLevel.moderate,
  DustLevel.unhealthy, DustLevel.good,
];

/// 예보 가능 범위(2주치) 날씨 점수 — 패턴이 한눈에 보이도록 변동 포함.
final List<WeatherDay> mockWeatherDays = List.generate(_scores.length, (i) {
  final score = _scores[i];
  return WeatherDay(
    date: _d(i),
    score: score,
    temperature: 14 + (i % 6),
    precipitationChance: (100 - score).clamp(5, 90),
    windSpeed: 6 + (i % 5),
    precipitation: _precipitations[i],
    dustLevel: _dustLevels[i],
  );
});

/// 내가 등록한 라이딩 일정 (초기값 비어있음 — 실제 사용자 데이터로만 채워짐).
final List<RidingSchedule> mockSchedules = [];

/// 최근 등록 시 자주 쓴 코스명 — 일정 등록 화면 즐겨찾기 드롭다운 (US-004 AC3, 최대 5개).
const mockFavoriteCourses = <String>[
  '한강 자유로 코스',
  '남산 순환 코스',
  '북악 스카이웨이',
  '한강 잠실 코스',
  '양재천 라이딩',
];

/// 그룹 라이딩 참석 현황 (초기값 비어있음 — 실제 사용자 데이터로만 채워짐).
final List<GroupReservation> mockGroupReservations = [];
