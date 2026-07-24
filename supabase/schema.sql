-- ============================================================
--  FRONT-X 투자영업실 · 주간 KPI 트래커 · Supabase 스키마
--  Supabase Dashboard → SQL Editor 에 통째로 붙여넣고 RUN 하세요.
--  (여러 번 실행해도 안전합니다)
-- ============================================================

-- ------------------------------------------------------------
-- 1. 공통 설정 (KPI 항목 정의 / 등급 정의 / 사이드바 제목)
--    항상 id = 1 인 단 한 줄만 존재합니다.
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
--    id 는 앱이 생성하는 문자열 키('legacy', 'agent_1712...' 등)
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
--
--    ※ agent_id 에 일부러 FK 를 걸지 않았습니다.
--      담당자를 목록에서 삭제해도 그동안 입력한 실적은
--      "전체" 합계에 계속 반영되어야 하기 때문입니다.
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
-- 4. updated_at 자동 갱신 트리거
-- ------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
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
-- 5. RLS (Row Level Security)
--    기본 정책: "로그인한 사용자만 읽고 쓸 수 있음"
--    → 로그인하지 않은 사람은 anon key 를 알아도 데이터를 볼 수 없습니다.
--    사용자 계정은 Supabase Dashboard → Authentication → Users 에서 직접 생성합니다.
-- ------------------------------------------------------------
alter table public.app_config   enable row level security;
alter table public.agents       enable row level security;
alter table public.week_entries enable row level security;

drop policy if exists "authenticated all" on public.app_config;
drop policy if exists "authenticated all" on public.agents;
drop policy if exists "authenticated all" on public.week_entries;

create policy "authenticated all" on public.app_config
  for all to authenticated using (true) with check (true);

create policy "authenticated all" on public.agents
  for all to authenticated using (true) with check (true);

create policy "authenticated all" on public.week_entries
  for all to authenticated using (true) with check (true);

-- ------------------------------------------------------------
-- 6. Realtime (여러 명이 동시에 열어두면 서로의 입력이 즉시 반영됨)
-- ------------------------------------------------------------
do $$
begin
  begin
    alter publication supabase_realtime add table public.week_entries;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.agents;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.app_config;
  exception when duplicate_object then null;
  end;
end $$;

-- ------------------------------------------------------------
-- 7. 기본 데이터 시드 (이미 값이 있으면 건드리지 않음)
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
