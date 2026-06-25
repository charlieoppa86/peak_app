/// 그룹 화면 목 데이터. 추후 실제 그룹/초대 API 연동 시 이 파일만 교체하면 된다.
library;

enum AttendeeStatus { confirmed, pending, declined }

class Attendee {
  const Attendee({required this.name, required this.status});

  final String name;
  final AttendeeStatus status;
}

class GroupSchedule {
  const GroupSchedule({
    required this.id,
    required this.courseName,
    required this.date,
    required this.time,
    required this.organizerName,
    required this.isMine,
    required this.attendees,
  });

  final String id;
  final String courseName;
  final DateTime date;
  final String time;

  /// 오거나이저 이름. 내가 만든 일정이면 '나'.
  final String organizerName;

  /// true면 내가 만든 그룹 일정, false면 초대받은 일정.
  final bool isMine;
  final List<Attendee> attendees;

  int get confirmedCount => attendees.where((a) => a.status == AttendeeStatus.confirmed).length;
  int get pendingCount => attendees.where((a) => a.status == AttendeeStatus.pending).length;
  int get invitedCount => attendees.length;
}

/// 내가 만든 그룹 일정 / 초대받은 그룹 일정 (초기값 비어있음 — 실제 사용자 데이터로만 채워짐).
final List<GroupSchedule> mockGroupSchedules = [];
