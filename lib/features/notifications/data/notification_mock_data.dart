/// 알림 인박스 목 데이터. 추후 실제 푸시/서버 연동 시 이 파일만 교체하면 된다.
library;

import 'package:firebase_messaging/firebase_messaging.dart';

enum NotificationType { weatherAlert, weeklySummary, groupChange }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.read = false,
    this.scheduleId,
    this.groupId,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime receivedAt;
  final bool read;

  /// 날씨 악화 알림 탭 시 대안 날짜가 미리 선택된 일정 편집 화면으로 이동 (US-007 AC3).
  final String? scheduleId;

  /// 그룹 일정 변경 알림 탭 시 그룹 일정 상세로 이동.
  final String? groupId;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        receivedAt: receivedAt,
        read: read ?? this.read,
        scheduleId: scheduleId,
        groupId: groupId,
      );

  /// FCM RemoteMessage → AppNotification 변환.
  /// data payload: { "type": "weather_alert|weekly_summary|group_change",
  ///                 "scheduleId": "s1", "groupId": "g1" }
  factory AppNotification.fromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final type = switch (data['type'] as String?) {
      'weather_alert' => NotificationType.weatherAlert,
      'weekly_summary' => NotificationType.weeklySummary,
      'group_change' => NotificationType.groupChange,
      _ => NotificationType.weatherAlert,
    };
    return AppNotification(
      id: message.messageId ?? '${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
      receivedAt: DateTime.now(),
      scheduleId: data['scheduleId'] as String?,
      groupId: data['groupId'] as String?,
    );
  }
}

/// "N시간/일 전" 형태로 항상 과거 시각이 되도록 현재 기준 상대 시간으로 계산한다.
DateTime _ago({int days = 0, int hours = 0, int minutes = 0}) =>
    DateTime.now().subtract(Duration(days: days, hours: hours, minutes: minutes));

/// 날씨 악화 · 주간 TOP 3 요약 · 그룹 일정 변경 알림 인박스 (US-007, US-008).
final List<AppNotification> mockNotifications = [
  AppNotification(
    id: 'n1',
    type: NotificationType.weatherAlert,
    title: '날씨가 갑자기 나빠졌어요',
    body: '한강 자유로 코스(오늘) 강수확률이 52%p 올랐어요. 대신 6월 10일 오전 7시대가 점수 88점으로 좋아요.',
    receivedAt: _ago(hours: 2, minutes: 15),
    scheduleId: 's1',
  ),
  AppNotification(
    id: 'n2',
    type: NotificationType.weeklySummary,
    title: '이번 주 라이딩 TOP 3',
    body: '이번 주 라이딩하기 좋은 시간대 3곳을 골라봤어요. 캘린더에서 하이라이트로 확인해보세요.',
    receivedAt: _ago(days: 1, hours: 6),
    read: true,
  ),
  AppNotification(
    id: 'n3',
    type: NotificationType.groupChange,
    title: '그룹 일정이 변경됐어요',
    body: '한유진님이 "북한산 둘레길 라이딩" 일정을 6월 16일 오전 8시로 변경했어요. 참석 여부를 다시 알려주세요.',
    receivedAt: _ago(days: 1, hours: 14),
    groupId: 'g4',
  ),
  AppNotification(
    id: 'n4',
    type: NotificationType.weatherAlert,
    title: '강수 확률이 높아지고 있어요',
    body: '남산 순환 코스(6월 10일) 강수확률이 58%p 상승했어요. 대신 6월 11일 오전 6시대가 점수 91점으로 좋아요.',
    receivedAt: _ago(days: 2, hours: 9),
    read: true,
    scheduleId: 's2',
  ),
  AppNotification(
    id: 'n5',
    type: NotificationType.groupChange,
    title: '참석 응답 마감이 다가와요',
    body: '"남산 순환 코스 같이 달리기" 일정에 미응답 멤버가 2명 있어요. 리마인드를 보내보세요.',
    receivedAt: _ago(days: 3, hours: 7),
    read: true,
    groupId: 'g1',
  ),
];
