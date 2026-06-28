import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL']!;
  // Supabase v2.9+ 에서 anonKey → publishableKey로 명칭 변경됨 (동일한 키)
  static String get supabasePublishableKey => dotenv.env['SUPABASE_ANON_KEY']!;

  // 카카오 네이티브 앱 키. 미설정 시 빈 문자열 — 카카오 로그인만 비활성화되고
  // 앱의 나머지 기능(혼자 달리기·날씨)은 정상 동작한다.
  static String get kakaoNativeAppKey => dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? '';
}
