import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../router/app_router.dart';

// ─── 백그라운드 핸들러 (top-level 함수 필수) ─────────────────────────────────
//
// 앱이 백그라운드/종료 상태일 때 FCM 메시지 수신 시 별도 isolate에서 호출된다.
// Firebase는 main isolate에서 이미 초기화됐으나 isolate가 다르므로 재초기화 없이
// 최소한의 작업(로깅, 로컬 DB 저장 등)만 수행한다.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  debugPrint('[FCM] 백그라운드 수신 — id: ${message.messageId}, '
      'title: ${message.notification?.title}');
  // TODO: 로컬 알림 저장, 배지 업데이트 등
}

// ─── FCM 서비스 ──────────────────────────────────────────────────────────────

/// FCM 초기화, 권한 요청, 토큰 관리, 메시지 라우팅을 담당하는 정적 서비스.
///
/// 사용 순서:
/// 1. main()에서 Firebase.initializeApp() 직후 → [registerBackgroundHandler]
/// 2. runApp() 이후 앱이 준비되면 → [initialize]
abstract final class PushNotificationService {
  static final _messaging = FirebaseMessaging.instance;

  // 포그라운드 메시지를 앱 내 다른 위젯에서 구독할 수 있도록 broadcast로 노출
  static final _foregroundController = StreamController<RemoteMessage>.broadcast();

  static Stream<RemoteMessage> get foregroundMessages =>
      _foregroundController.stream;

  /// 발급된 FCM 토큰. initialize() 완료 후 사용 가능.
  static String? _token;
  static String? get token => _token;

  // ─── 1단계: runApp() 이전 ────────────────────────────────────────────────

  /// 백그라운드 메시지 핸들러를 등록한다.
  /// [runApp] 이전 · [Firebase.initializeApp] 이후에 반드시 호출해야 한다.
  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
  }

  // ─── 2단계: runApp() 이후 ────────────────────────────────────────────────

  /// 권한 요청 → 토큰 발급 → 포그라운드·탭 핸들러 등록.
  ///
  /// 권한 거부 시 null 반환. 에러 발생 시 로그 후 null 반환(앱 크래시 없음).
  static Future<String?> initialize() async {
    try {
      return await _initialize();
    } catch (e, st) {
      debugPrint('[FCM] initialize 실패: $e\n$st');
      return null;
    }
  }

  static Future<String?> _initialize() async {
    // 1. 알림 권한 요청 (iOS 필수 / Android 13+ 필수)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false, // 임시 권한 없이 명시적 동의만 허용
    );

    debugPrint('[FCM] 권한 상태: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] 권한 거부 — 푸시 알림 비활성화');
      return null;
    }

    // 2. iOS: 앱 포그라운드 상태에서도 알림 배너·뱃지·사운드 표시
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. FCM 토큰 발급 (서버로 전송해 특정 기기에 푸시 발송 시 사용)
    _token = await _messaging.getToken();
    debugPrint('[FCM] 토큰: $_token');

    // 4. 토큰 갱신 구독 (토큰은 주기적으로 교체될 수 있음)
    _messaging.onTokenRefresh.listen((newToken) {
      _token = newToken;
      debugPrint('[FCM] 토큰 갱신: $newToken');
      // TODO: 서버 API 호출로 새 토큰 업로드
    });

    // 5. 포그라운드 메시지 수신
    //    - Android: 자동 알림 배너가 뜨지 않으므로 앱 내 처리 필요
    //    - iOS: setForegroundNotificationPresentationOptions 설정으로 OS가 표시
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[FCM] 포그라운드 수신 — title: ${message.notification?.title}');
      _foregroundController.add(message); // 알림 화면 등에서 구독 가능
    });

    // 6. 백그라운드 상태에서 알림 탭 → 앱 포커스 전환
    FirebaseMessaging.onMessageOpenedApp.listen(_routeFromMessage);

    // 7. 종료 상태에서 알림 탭으로 콜드 스타트된 경우
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM] 콜드 스타트 메시지: ${initialMessage.data}');
      _routeFromMessage(initialMessage);
    }

    return _token;
  }

  // ─── 토픽 구독 ───────────────────────────────────────────────────────────

  /// 앱 기본 토픽. 서버에서 전체 사용자 대상 브로드캐스트 시 사용.
  static const _defaultTopics = [
    'weather_alerts',   // 날씨 악화 경보
    'weekly_summary',   // 주간 TOP 3 요약
    'group_updates',    // 그룹 일정 변경
  ];

  /// 권한 허용 후 기본 토픽 전체 구독. initialize() 완료 콜백에서 호출한다.
  static Future<void> subscribeToDefaultTopics() async {
    for (final topic in _defaultTopics) {
      await _messaging.subscribeToTopic(topic);
      debugPrint('[FCM] 토픽 구독: $topic');
    }
  }

  /// 특정 토픽 구독 (예: 지역별 날씨 알림 'region_seoul').
  static Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('[FCM] 토픽 구독: $topic');
  }

  /// 특정 토픽 구독 해제.
  static Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('[FCM] 토픽 구독 해제: $topic');
  }

  // ─── 딥링크 라우팅 ───────────────────────────────────────────────────────

  /// 알림 탭 시 data payload의 type에 따라 해당 화면으로 이동한다.
  ///
  /// 서버 payload 예시:
  /// ```json
  /// { "type": "weather_alert", "scheduleId": "s1" }
  /// { "type": "group_change",  "groupId": "g1"    }
  /// { "type": "weekly_summary"                     }
  /// ```
  static void _routeFromMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;
    final scheduleId = data['scheduleId'] as String?;
    final groupId = data['groupId'] as String?;

    debugPrint('[FCM] 알림 탭 라우팅 — type: $type');

    switch (type) {
      case 'weather_alert':
        // 날씨 악화: 일정 수정 화면으로 바로 진입 (대안 날짜 선택)
        if (scheduleId != null) {
          appRouter.push('/home/schedule/$scheduleId/edit');
        } else {
          appRouter.go('/home');
        }
      case 'group_change':
        // 그룹 일정 변경: 해당 그룹 상세 화면
        if (groupId != null) {
          appRouter.push('/group/$groupId');
        } else {
          appRouter.go('/group');
        }
      case 'weekly_summary':
        // 주간 TOP 3 요약: 홈 화면
        appRouter.go('/home');
      default:
        // 타입 미정 또는 일반 알림: 알림 목록
        appRouter.go('/notifications');
    }
  }
}
