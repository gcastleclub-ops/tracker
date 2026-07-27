-- ============================================================
--  FRONT-X 투자영업실 · 주간 KPI 트래커 · Supabase 스키마
--  Supabase Dashboard → SQL Editor 에 통째로 붙여넣고 RUN 하세요.
--  (여러 번 실행해도 안전합니다)
--
--  권한 모델
--   - 로그인 안 함(anon) : 전체 열람만 가능, 수정 불가
--   - 관리자(is_admin)   : 전체 수정 가능 (KPI 항목/등급/담당자/모든 실적)
--   - 담당자(agent_id)   : 본인에게 할당된 담당자의 실적만 수정 가능
-- ============================================================

-- ------------------------------------------------------------
-- 1. 공통 설정 (KPI 항목 정의 / 등급 정의 / 사이드바 제목)
-- ------------------------------------------------------------
create table if not exists public.app_config (
  id          smallint primary key default 1,
  title       text        not null default 'FRONT-X 투자영업실',
  subtitle    text        not null default '주간 영업 KPI 보고 트래커',
  items       jsonb       not null default '[]'::jsonb,
  grade_defs  jsonb       not null default '{}'::jsonb,
  updated_at  timestamptz not null default now(),
  constraint app_config_singleton check (id = 1)
);

-- ------------------------------------------------------------
-- 2. 담당자 목록
-- ------------------------------------------------------------
create table if not exists public.agents (
  id          text primary key,
  name        text        not null,
  sort_order  int         not null default 0,
  created_at  timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 3. 주차 × 담당자 실적 (앱의 핵심 데이터)
--    week_key 형식: 'YYYY-MM-W'  예) '2026-07-2'
--    담당자를 목록에서 삭제해도 실적은 남아 "전체" 합계에 계속 반영되도록 FK 없음
-- ------------------------------------------------------------
create table if not exists public.week_entries (
  week_key     text not null,
  agent_id     text not null,
  title        text        not null default '',
  items        jsonb       not null default '{}'::jsonb,
  grades       jsonb       not null default '{}'::jsonb,
  meta_inbound jsonb       not null default '{}'::jsonb,
  updated_at   timestamptz not null default now(),
  primary key (week_key, agent_id)
);

create index if not exists week_entries_week_key_idx on public.week_entries (week_key);
create index if not exists week_entries_agent_id_idx on public.week_entries (agent_id);

-- ------------------------------------------------------------
-- 4. 멤버(권한) 테이블 : 로그인 사용자 ↔ 역할/담당자 매핑
--    user_id   : auth.users 의 uuid
--    is_admin  : true 면 전체 수정 가능
--    agent_id  : 이 사용자가 수정할 수 있는 담당자 (agents.id 와 같은 값)
--
--    ※ 이 표의 행은 관리자가 아래 "8. 초기 세팅"처럼 SQL 로 직접 넣습니다.
--      (앱 화면에는 멤버 관리 UI를 두지 않아, 권한을 코드로만 통제)
-- ------------------------------------------------------------
create table if not exists public.members (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  is_admin   boolean     not null default false,
  agent_id   text,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 5. updated_at 자동 갱신 트리거
-- ------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

drop trigger if exists app_config_touch    on public.app_config;
drop trigger if exists week_entries_touch  on public.week_entries;

create trigger app_config_touch
  before update on public.app_config
  for each row execute function public.touch_updated_at();

create trigger week_entries_touch
  before update on public.week_entries
  for each row execute function public.touch_updated_at();

-- ------------------------------------------------------------
-- 6. 권한 판별 헬퍼 (SECURITY DEFINER → members 의 RLS 재귀를 피함)
-- ------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select m.is_admin from public.members m where m.user_id = auth.uid()), false);
$$;

create or replace function public.my_agent_id()
returns text
language sql stable security definer set search_path = public as $$
  select m.agent_id from public.members m where m.user_id = auth.uid();
$$;

-- ------------------------------------------------------------
-- 7. RLS 정책
-- ------------------------------------------------------------
alter table public.app_config   enable row level security;
alter table public.agents       enable row level security;
alter table public.week_entries enable row level security;
alter table public.members      enable row level security;

-- 이전 버전(로그인 전용) 정책 정리
drop policy if exists "authenticated all" on public.app_config;
drop policy if exists "authenticated all" on public.agents;
drop policy if exists "authenticated all" on public.week_entries;

-- 데이터 3종: 누구나 열람(anon 포함)
drop policy if exists "read all (public)" on public.app_config;
drop policy if exists "read all (public)" on public.agents;
drop policy if exists "read all (public)" on public.week_entries;
create policy "read all (public)" on public.app_config   for select to anon, authenticated using (true);
create policy "read all (public)" on public.agents       for select to anon, authenticated using (true);
create policy "read all (public)" on public.week_entries for select to anon, authenticated using (true);

-- 설정/담당자 수정: 관리자만
drop policy if exists "admin write" on public.app_config;
drop policy if exists "admin write" on public.agents;
create policy "admin write" on public.app_config for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admin write" on public.agents     for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- 실적 수정: 관리자 전체 / 담당자는 본인 몫만
drop policy if exists "admin write entries" on public.week_entries;
drop policy if exists "own write entries"   on public.week_entries;
create policy "admin write entries" on public.week_entries
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "own write entries" on public.week_entries
  for all to authenticated
  using (agent_id = public.my_agent_id())
  with check (agent_id = public.my_agent_id());

-- 멤버 표: 본인 것 또는 관리자만 열람, 수정은 관리자만
drop policy if exists "read own or admin" on public.members;
drop policy if exists "admin manage members" on public.members;
create policy "read own or admin" on public.members
  for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy "admin manage members" on public.members
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- 테이블 접근 권한 (RLS 가 행 단위로 다시 제한함)
grant usage on schema public to anon, authenticated;
grant select on public.app_config, public.agents, public.week_entries to anon, authenticated;
grant insert, update, delete on public.app_config, public.agents, public.week_entries to authenticated;
grant select, insert, update, delete on public.members to authenticated;

-- ------------------------------------------------------------
-- 8. Realtime
-- ------------------------------------------------------------
do $$
begin
  begin alter publication supabase_realtime add table public.week_entries; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.agents;       exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.app_config;   exception when duplicate_object then null; end;
end $$;

-- ------------------------------------------------------------
-- 9. 기본 데이터 시드 (이미 값이 있으면 건드리지 않음)
-- ------------------------------------------------------------
insert into public.app_config (id, title, subtitle, items, grade_defs)
values (
  1,
  'FRONT-X 투자영업실',
  '주간 영업 KPI 보고 트래커',
  '[
    {"key":"visit",        "label":"신규 방문 업체",           "target":"월 150개"},
    {"key":"consult",      "label":"대표 상담",                "target":"월 20건"},
    {"key":"quote",        "label":"견적 발송",                "target":"월 5건"},
    {"key":"contract",     "label":"계약 체결",                "target":"월 1~3건"},
    {"key":"prospect",     "label":"가망업체 확보",            "target":"월 5~8건"},
    {"key":"revisit",      "label":"재방문 관리",              "target":"월 10~15건"},
    {"key":"metaResponse", "label":"메타광고 문의 대응(건)",   "target":"100%"}
  ]'::jsonb,
  '{
    "A":"결정권자 상담완료 / 도입시기 구체적 언급",
    "B":"관심 업체 / 설치예산 미정 / 재방문 필요",
    "C":"가격 민감 / 담당자만 응대, 결정권자 미접촉",
    "D":"확실한 거절 / 여관급 모텔 (Drop)"
  }'::jsonb
)
on conflict (id) do nothing;

-- ============================================================
-- 10. 초기 세팅 — 아래를 필요에 맞게 고쳐 "따로" 실행하세요
-- ============================================================
-- (1) 먼저 Authentication → Users 에서 관리자/담당자 계정을 만든 뒤,
--
-- (2) 관리자 지정 : 이메일을 본인 관리자 계정으로 바꿔 실행
--   insert into public.members (user_id, is_admin)
--   select id, true from auth.users where email = 'admin@frontx.co.kr'
--   on conflict (user_id) do update set is_admin = true;
--
-- (3) 담당자 배정 : 로그인 계정 ↔ agents.id 매핑
--   -- agents.id 확인:  select id, name from public.agents;
--   insert into public.members (user_id, agent_id)
--   select id, 'legacy' from auth.users where email = 'park@frontx.co.kr'
--   on conflict (user_id) do update set agent_id = excluded.agent_id;
