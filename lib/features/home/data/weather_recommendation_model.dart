/// Edge Function `weather-forecast`의 응답과 1:1 대응.
class RidingRecommendation {
  const RidingRecommendation({
    required this.weather,
    required this.temperature,
    required this.wind,
    required this.recommendedTimeSlot,
    required this.recommendation,
    required this.reason,
    this.forecast = const [],
  });

  final String weather;
  final String temperature;
  final String wind;
  final String recommendedTimeSlot;
  final RecommendationLevel recommendation;
  final String reason;
  final List<ForecastDay> forecast;

  /// 추천 레벨 → 대표 점수 (schedule_detail 등에서 사용).
  int get score => switch (recommendation) {
        RecommendationLevel.good => 85,
        RecommendationLevel.normal => 60,
        RecommendationLevel.bad => 25,
      };

  /// "22°C" 형태의 문자열에서 정수 파싱.
  int get temperatureInt {
    final digits = temperature.replaceAll(RegExp(r'[^0-9\-]'), '');
    return int.tryParse(digits) ?? 0;
  }

  factory RidingRecommendation.fromJson(Map<String, dynamic> json) {
    final forecastJson = json['forecast'] as List<dynamic>? ?? [];
    return RidingRecommendation(
      weather: json['weather'] as String,
      temperature: json['temperature'] as String,
      wind: json['wind'] as String,
      recommendedTimeSlot: json['recommendedTimeSlot'] as String,
      recommendation: RecommendationLevel.fromString(json['recommendation'] as String),
      reason: json['reason'] as String,
      forecast: forecastJson
          .map((e) => ForecastDay.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// API가 반환하는 날별 예보 (캘린더용).
class ForecastDay {
  const ForecastDay({
    required this.date,
    required this.score,
    required this.temperature,
    required this.precipitationChance,
    required this.windSpeed,
  });

  final String date; // "YYYYMMDD"
  final int score;
  final int temperature;
  final int precipitationChance;
  final double windSpeed;

  DateTime get dateTime {
    final y = int.parse(date.substring(0, 4));
    final m = int.parse(date.substring(4, 6));
    final d = int.parse(date.substring(6, 8));
    return DateTime(y, m, d);
  }

  factory ForecastDay.fromJson(Map<String, dynamic> json) => ForecastDay(
        date: json['date'] as String,
        score: (json['score'] as num).toInt(),
        temperature: (json['temperature'] as num).toInt(),
        precipitationChance: (json['precipitationChance'] as num).toInt(),
        windSpeed: (json['windSpeed'] as num).toDouble(),
      );
}

enum RecommendationLevel {
  good('추천'),
  normal('보통'),
  bad('비추천');

  const RecommendationLevel(this.label);

  final String label;

  static RecommendationLevel fromString(String value) => switch (value) {
        '추천' => RecommendationLevel.good,
        '보통' => RecommendationLevel.normal,
        _ => RecommendationLevel.bad,
      };
}

/// Edge Function이 반환하는 구조화 에러.
class WeatherFetchException implements Exception {
  const WeatherFetchException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => '[$code] $message';
}
