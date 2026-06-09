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

DateTime _today = DateTime.now();
DateTime _d(int dayOffset) => DateTime(_today.year, _today.month, _today.day).add(Duration(days: dayOffset));

/// 내가 만든 그룹 일정 / 초대받은 그룹 일정 — 그룹 목록 화면에서 구분 표시 (docs/ia.md 그룹 IA).
final List<GroupSchedule> mockGroupSchedules = [
  GroupSchedule(
    id: 'g1',
    courseName: '남산 순환 코스 같이 달리기',
    date: _d(2),
    time: '오전 6:30',
    organizerName: '나',
    isMine: true,
    attendees: const [
      Attendee(name: '김지훈', status: AttendeeStatus.confirmed),
      Attendee(name: '박서연', status: AttendeeStatus.confirmed),
      Attendee(name: '이도윤', status: AttendeeStatus.confirmed),
      Attendee(name: '최민재', status: AttendeeStatus.confirmed),
      Attendee(name: '정하늘', status: AttendeeStatus.pending),
      Attendee(name: '오세준', status: AttendeeStatus.pending),
    ],
  ),
  GroupSchedule(
    id: 'g2',
    courseName: '한강 잠실 코스 주말 라이딩',
    date: _d(5),
    time: '오후 2:00',
    organizerName: '나',
    isMine: true,
    attendees: const [
      Attendee(name: '한유진', status: AttendeeStatus.confirmed),
      Attendee(name: '서지우', status: AttendeeStatus.confirmed),
      Attendee(name: '강민수', status: AttendeeStatus.pending),
      Attendee(name: '윤소희', status: AttendeeStatus.pending),
      Attendee(name: '임재현', status: AttendeeStatus.pending),
      Attendee(name: '배수아', status: AttendeeStatus.declined),
      Attendee(name: '조은우', status: AttendeeStatus.pending),
      Attendee(name: '신예린', status: AttendeeStatus.pending),
    ],
  ),
  GroupSchedule(
    id: 'g3',
    courseName: '양재천 아침 라이딩',
    date: _d(3),
    time: '오전 7:00',
    organizerName: '김지훈',
    isMine: false,
    attendees: const [
      Attendee(name: '김지훈', status: AttendeeStatus.confirmed),
      Attendee(name: '박서연', status: AttendeeStatus.confirmed),
      Attendee(name: '나', status: AttendeeStatus.pending),
      Attendee(name: '최민재', status: AttendeeStatus.confirmed),
    ],
  ),
  GroupSchedule(
    id: 'g4',
    courseName: '북한산 둘레길 라이딩',
    date: _d(8),
    time: '오전 8:00',
    organizerName: '한유진',
    isMine: false,
    attendees: const [
      Attendee(name: '한유진', status: AttendeeStatus.confirmed),
      Attendee(name: '나', status: AttendeeStatus.confirmed),
      Attendee(name: '서지우', status: AttendeeStatus.confirmed),
    ],
  ),
];
