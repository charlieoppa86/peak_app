import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 클라이언트 접근점 + 익명 세션 관리.
///
/// Peak은 로그인 없이 바로 사용하는 앱(US-002)이므로
/// 첫 실행 시 익명 계정을 자동 생성해 auth.uid() 기반 RLS를 적용한다.
/// 기기에 세션이 이미 있으면 재사용 — 재설치 시에만 새 익명 계정이 만들어진다.
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  /// 세션이 없을 때만 익명 로그인. 이미 세션이 있으면 아무것도 안 함.
  static Future<void> ensureSession() async {
    if (client.auth.currentSession != null) return;
    await client.auth.signInAnonymously();
  }

  static String? get currentUserId => client.auth.currentUser?.id;
}
