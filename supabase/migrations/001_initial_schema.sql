-- Peak — 초기 스키마
-- Supabase 대시보드 > SQL Editor에서 실행하거나 supabase db push로 적용.
-- 익명 로그인(signInAnonymously) 기반 — auth.users에 익명 계정이 자동 생성되고
-- 모든 테이블은 auth.uid() 기준 RLS로 보호된다.

-- ─── profiles ────────────────────────────────────────────────────────────────
-- 온보딩에서 입력한 이름·지역·선호 요일 (US-001, US-002)
create table public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  name          text not null,
  city          text not null,
  district      text not null,
  preferred_days text[] not null default '{}',
  created_at    timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "own profile read"   on public.profiles for select using (auth.uid() = id);
create policy "own profile insert" on public.profiles for insert with check (auth.uid() = id);
create policy "own profile update" on public.profiles for update using (auth.uid() = id);

-- ─── riding_schedules ────────────────────────────────────────────────────────
-- 개인 라이딩 일정 (US-004, US-009)
create table public.riding_schedules (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  date        date not null,
  time        text not null,          -- 표시용 레이블 ex) "오전 7:00"
  course_name text not null,
  type        text not null check (type in ('solo', 'group')),
  status      text not null default 'upcoming' check (status in ('upcoming', 'completed')),
  created_at  timestamptz not null default now()
);

alter table public.riding_schedules enable row level security;

create policy "own schedules"
  on public.riding_schedules for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ─── group_schedules ─────────────────────────────────────────────────────────
-- 그룹 라이딩 이벤트 (US-005, US-010)
create table public.group_schedules (
  id                  uuid primary key default gen_random_uuid(),
  organizer_id        uuid not null references public.profiles(id) on delete cascade,
  riding_schedule_id  uuid references public.riding_schedules(id) on delete set null,
  title               text not null,
  -- 초대 링크 토큰: /invite/:token 형태로 공유 (US-006)
  invite_token        text not null unique default encode(gen_random_bytes(16), 'hex'),
  created_at          timestamptz not null default now()
);

alter table public.group_schedules enable row level security;

-- 오거나이저: 모든 CRUD
create policy "organizer manages group"
  on public.group_schedules for all
  using (auth.uid() = organizer_id)
  with check (auth.uid() = organizer_id);

-- 초대받은 사람(비로그인 포함): invite_token으로 조회 가능
create policy "public read by token"
  on public.group_schedules for select
  using (true);

-- ─── group_attendees ─────────────────────────────────────────────────────────
-- 그룹 일정 참석자 — 앱 설치·로그인 없이 이름만 입력해 참석 (US-006)
create table public.group_attendees (
  id                uuid primary key default gen_random_uuid(),
  group_schedule_id uuid not null references public.group_schedules(id) on delete cascade,
  name              text not null,
  created_at        timestamptz not null default now()
);

alter table public.group_attendees enable row level security;

-- 누구나 참석 등록 가능 (초대 랜딩 웹페이지에서 이름 입력 시)
create policy "anyone can attend"
  on public.group_attendees for insert
  with check (true);

-- 참석자 목록은 누구나 조회 가능
create policy "anyone can read attendees"
  on public.group_attendees for select
  using (true);
