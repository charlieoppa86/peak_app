import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL']!;
  // Supabase v2.9+ 에서 anonKey → publishableKey로 명칭 변경됨 (동일한 키)
  static String get supabasePublishableKey => dotenv.env['SUPABASE_ANON_KEY']!;
}
