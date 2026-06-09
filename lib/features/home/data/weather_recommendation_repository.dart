import 'package:supabase_flutter/supabase_flutter.dart';

import 'weather_recommendation_model.dart';

class WeatherRecommendationRepository {
  const WeatherRecommendationRepository(this._client);

  final SupabaseClient _client;

  /// Edge Function `weather-forecast` 호출 → [RidingRecommendation] 반환.
  /// 오류 시 [WeatherFetchException] throw (code, message 포함).
  Future<RidingRecommendation> fetch({double? lat, double? lng}) async {
    try {
      final res = await _client.functions.invoke(
        'weather-forecast',
        body: {'lat': lat, 'lng': lng},
      );

      final data = res.data;

      // Edge Function이 에러 JSON을 2xx로 반환한 경우 방어
      if (data is Map<String, dynamic> && data.containsKey('code')) {
        throw WeatherFetchException(
          code: data['code'] as String? ?? 'UNKNOWN',
          message: data['message'] as String? ?? '알 수 없는 오류',
        );
      }

      return RidingRecommendation.fromJson(data as Map<String, dynamic>);
    } on FunctionException catch (e) {
      final details = e.details;
      throw WeatherFetchException(
        code: details is Map ? (details['code'] as String? ?? 'INTERNAL_ERROR') : 'INTERNAL_ERROR',
        message: details is Map
            ? (details['message'] as String? ?? (e.reasonPhrase ?? '서버 오류'))
            : (e.reasonPhrase ?? '서버 오류'),
      );
    } on WeatherFetchException {
      rethrow;
    } catch (e) {
      throw WeatherFetchException(code: 'INTERNAL_ERROR', message: e.toString());
    }
  }
}
