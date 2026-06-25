-- 일정 공유 시 참석 여부를 저장하는 테이블.
-- riding_schedule_id: 어떤 일정에 대한 응답인지
-- 앱 없는 사람도 웹에서 이름/상태를 제출할 수 있도록 insert는 공개 허용.
create table public.schedule_rsvps (
  id                  uuid primary key default gen_random_uuid(),
  riding_schedule_id  text not null,   -- RidingSchedule.id (로컬 UUID 문자열)
  name                text not null,
  status              text not null check (status in ('attending', 'maybe', 'declined')),
  created_at          timestamptz not null default now()
);

alter table public.schedule_rsvps enable row level security;

-- 누구나 참석 응답 등록 가능 (앱 없는 사람 포함)
create policy "anyone can rsvp"
  on public.schedule_rsvps for insert
  with check (true);

-- 누구나 특정 일정의 참석자 목록 조회 가능
create policy "anyone can read rsvps"
  on public.schedule_rsvps for select
  using (true);
