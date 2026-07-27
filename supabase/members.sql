-- ============================================================
--  FRONT-X KPI 트래커 · 권한(멤버) 설정
--  Supabase Dashboard → SQL Editor 에 붙여넣고 RUN
--  (여러 번 실행해도 안전합니다)
--
--  ※ 먼저 Authentication → Users → Add user 로 계정을 만들어야 합니다.
--    계정을 만들 때 "Auto Confirm User" 를 반드시 체크하세요.
--    계정이 없으면 아래 insert 가 조용히 아무것도 하지 않습니다.
--    → 맨 아래 확인 쿼리로 결과를 꼭 확인하세요.
--
--  현재 담당자 id (앱의 ⚙ 담당자 관리에서 이름을 바꿔도 id 는 그대로라 매핑이 유지됩니다)
--    legacy          = 박상욱
--    agent_default_1 = 담당자1
--    agent_default_2 = 담당자2
-- ============================================================

-- ------------------------------------------------------------
-- 1) 전체 관리자 (담당자 배정 없음)
-- ------------------------------------------------------------
insert into public.members (user_id, is_admin, agent_id)
select id, true, null from auth.users where email = 'admin@gmail.com'
on conflict (user_id) do update set is_admin = true;

-- ------------------------------------------------------------
-- 2) 관리자 + 박상욱 담당 겸직
--    is_admin 이 true 라 어차피 전체를 수정할 수 있고,
--    agent_id 를 함께 두면 로그인 시 박상욱 탭으로 바로 이동합니다.
-- ------------------------------------------------------------
insert into public.members (user_id, is_admin, agent_id)
select id, true, 'legacy' from auth.users where email = 'gcastleclub@gmail.com'
on conflict (user_id) do update set is_admin = true, agent_id = 'legacy';

-- ------------------------------------------------------------
-- 3) 담당자1 — 본인 실적만 수정 가능
-- ------------------------------------------------------------
insert into public.members (user_id, is_admin, agent_id)
select id, false, 'agent_default_1' from auth.users where email = 'test1@jienem.kr'
on conflict (user_id) do update set is_admin = false, agent_id = 'agent_default_1';

-- ------------------------------------------------------------
-- 4) 담당자2 — 본인 실적만 수정 가능
-- ------------------------------------------------------------
insert into public.members (user_id, is_admin, agent_id)
select id, false, 'agent_default_2' from auth.users where email = 'test2@jienem.kr'
on conflict (user_id) do update set is_admin = false, agent_id = 'agent_default_2';


-- ============================================================
--  확인 쿼리 — 위 실행 후 반드시 이 결과를 보세요
--  "계정없음" 이 뜨면 Authentication → Users 에서 그 계정을 먼저 만들어야 합니다.
-- ============================================================
with want(email, 역할) as (
  values ('admin@gmail.com',       '관리자'),
         ('gcastleclub@gmail.com', '관리자 + 박상욱'),
         ('test1@jienem.kr',       '담당자1'),
         ('test2@jienem.kr',       '담당자2')
)
select
  w.email,
  w.역할                                as 의도한_역할,
  case
    when u.id is null       then '❌ 계정없음 — Users 에서 먼저 생성'
    when m.user_id is null  then '❌ 권한 미등록'
    when m.is_admin and m.agent_id is not null
                            then '✅ 관리자 + ' || coalesce(a.name, m.agent_id)
    when m.is_admin         then '✅ 관리자'
    when m.agent_id is not null
                            then '✅ 담당: ' || coalesce(a.name, m.agent_id)
    else '⚠ 열람 전용 (권한 없음)'
  end                                   as 실제_상태
from want w
left join auth.users    u on u.email    = w.email
left join public.members m on m.user_id = u.id
left join public.agents  a on a.id      = m.agent_id
order by w.email;


-- ============================================================
--  참고 — 권한 변경이 필요할 때
-- ============================================================
-- 관리자 권한 회수 :
--   update public.members set is_admin = false
--   where user_id = (select id from auth.users where email = '대상@메일');
--
-- 담당자 배정 해제 (열람 전용으로) :
--   update public.members set agent_id = null
--   where user_id = (select id from auth.users where email = '대상@메일');
--
-- 멤버 완전 삭제 (로그인은 되지만 열람 전용이 됨) :
--   delete from public.members
--   where user_id = (select id from auth.users where email = '대상@메일');
--
-- 전체 멤버 현황 :
--   select u.email, m.is_admin, a.name as agent
--   from public.members m
--   join auth.users u on u.id = m.user_id
--   left join public.agents a on a.id = m.agent_id
--   order by m.is_admin desc, u.email;
