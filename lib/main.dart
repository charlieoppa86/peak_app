import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/supabase_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    ),
  ]);
  // AdMob 초기화는 ATT 권한 요청 이후에 스플래시에서 수행한다.
  // 여기서 먼저 초기화하면 ATT 응답 전에 추적 데이터가 수집되어 Apple 정책 위반.

  // 백그라운드 핸들러는 runApp() 이전, Firebase 초기화 직후에 등록해야 한다.
  PushNotificationService.registerBackgroundHandler();

  // 세션이 없으면 익명 로그인으로 auth.uid() 확보 (RLS 적용 위해 필요).
  await SupabaseService.ensureSession();

  runApp(const ProviderScope(child: PeakApp()));

  // 권한 요청·토큰 발급·핸들러 등록. runApp() 이후 실행해 UI가 준비된 상태에서
  // 권한 다이얼로그가 표시되도록 한다. 권한 허용 시 기본 토픽 구독까지 연결.
  PushNotificationService.initialize()
      .then((_) => PushNotificationService.subscribeToDefaultTopics())
      .ignore();
}
