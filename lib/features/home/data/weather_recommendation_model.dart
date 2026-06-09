/// Edge Function `weather-forecast`의 응답과 1:1 대응.
/// 필드 추가/수정 시 Gemini responseSchema도 함께 갱신할 것.
class RidingRecommendation {
  const RidingRecommendation({
    required this.weather,
    required this.temperature,
    required this.wind,
    required this.recommendedTimeSlot,
    required this.recommendation,
    required this.reason,
  });

  final String weather;
  final String temperature;
  final String wind;
  final String recommendedTimeSlot;
  final RecommendationLevel recommendation;
  final String reason;

  factory RidingRecommendation.fromJson(Map<String, dynamic> json) {
    return RidingRecommendation(
      weather: json['weather'] as String,
      temperature: json['temperature'] as String,
      wind: json['wind'] as String,
      recommendedTimeSlot: json['recommendedTimeSlot'] as String,
      recommendation: RecommendationLevel.fromString(
        json['recommendation'] as String,
      ),
      reason: json['reason'] as String,
    );
  }
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
