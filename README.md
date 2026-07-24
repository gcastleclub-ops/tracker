# FRONT-X 투자영업실 · 주간 KPI 트래커

기존 단일 HTML 파일(브라우저 `localStorage` 저장) 버전을 **Supabase(DB·로그인·실시간) + GitHub Pages(호스팅)** 구조로 옮긴 버전입니다.

- 데이터는 브라우저가 아니라 **Supabase에 저장** → 어느 PC·휴대폰에서 열어도 같은 데이터
- **로그인한 팀원만** 접근 가능 (RLS 적용)
- 여러 명이 동시에 열어두면 **실시간으로 서로의 입력이 반영**
- 화면 상태(펼친 월, 선택한 주차 등)는 사람마다 다르므로 각자 브라우저에 저장

---

## 전체 순서

1. Supabase 프로젝트 생성 → `schema.sql` 실행
2. 팀원 계정 발급
3. `config.js`에 URL/키 입력
4. GitHub에 push → GitHub Pages 켜기
5. 기존 백업 JSON 업로드

---

## 1. Supabase 프로젝트 만들기

1. https://supabase.com 접속 → **New project**
   - Name: `frontx-kpi`
   - Region: **Northeast Asia (Seoul)** 권장
   - Database Password: 안전한 곳에 보관 (앱에서는 쓰지 않습니다)
2. 프로젝트 생성이 끝나면 좌측 **SQL Editor** → **New query**
3. 이 저장소의 [`supabase/schema.sql`](supabase/schema.sql) 내용을 **전부 복사해 붙여넣고 RUN**

테이블 3개(`app_config`, `agents`, `week_entries`), RLS 정책, 실시간 발행, 기본 KPI 항목이 한 번에 만들어집니다. 여러 번 실행해도 안전합니다.

## 2. 팀원 계정 만들기

좌측 **Authentication → Users → Add user → Create new user**

- Email / Password 입력
- **Auto Confirm User 체크** (메일 인증 절차 생략)

담당자 수만큼 반복합니다. 가입 화면은 따로 없고, 관리자가 여기서 발급한 계정으로만 로그인합니다.

### 로그인 유지 / 아이디 저장

로그인 화면에 체크박스 두 개가 있고, 둘 다 기본으로 켜져 있습니다. 설정은 브라우저별로 기억됩니다.

| 항목 | 켬 (기본) | 끔 |
|---|---|---|
| **로그인 유지** | 세션을 `localStorage`에 보관 → 브라우저를 닫았다 열어도 로그인 상태 | 세션을 `sessionStorage`에 보관 → 브라우저(탭)를 닫으면 로그아웃. 공용 PC용 |
| **아이디 저장** | 다음 방문 시 이메일이 자동 입력되고 커서가 비밀번호로 이동 | 매번 직접 입력 |

비밀번호는 어떤 경우에도 저장하지 않습니다. 로그아웃해도 저장된 아이디는 남습니다.

토큰은 만료 전에 자동 갱신되며, 갱신까지 실패하면 로그인 화면으로 돌아갑니다. 이때 **아직 저장되지 않은 입력은 메모리에 남아 있다가 다시 로그인하면 이어서 저장**되고, 보고 있던 주차·담당자 화면도 그대로 복원됩니다.

> 회원가입을 아예 막아두려면: **Authentication → Sign In / Providers → Email → "Allow new users to sign up" 끄기**

## 3. `config.js` 채우기

좌측 **Project Settings → API** 에서 두 값을 복사합니다.

```js
window.SUPABASE_CONFIG = {
  url:     'https://abcdefgh.supabase.co',   // Project URL
  anonKey: 'eyJhbGciOi...'                   // anon / public key
};
```

- `anon` 키는 브라우저에 공개되는 것이 **정상**입니다. 실제 통제는 RLS + 로그인이 담당합니다.
- `service_role` 키는 **절대** 넣지 마세요. 모든 보안을 우회합니다.

이 시점에서 `index.html`을 브라우저로 직접 열어 로그인·입력이 되는지 먼저 확인해도 됩니다.

## 4. GitHub에 올리고 Pages 켜기

저장소: https://github.com/gcastleclub-ops/tracker (연결 완료)

```bash
git push -u origin main
```

첫 push에서는 Git Credential Manager가 브라우저 로그인 창을 띄웁니다. 한 번만 인증하면 이후에는 저장됩니다.

그다음 저장소 **Settings → Pages**

- Source: **Deploy from a branch**
- Branch: **main** / **/ (root)** → Save

1~2분 뒤 https://gcastleclub-ops.github.io/tracker/ 로 접속됩니다.

> 저장소가 Public이라 `config.js`의 anon 키는 누구나 볼 수 있지만, 이는 설계상 정상입니다. RLS 정책이 로그인하지 않은 요청의 조회·수정을 모두 차단합니다(익명 쓰기 시도 시 `42501` 반환 확인 완료). `service_role` 키만 저장소에 넣지 마세요.

### Supabase에 도메인 등록

Supabase **Authentication → URL Configuration → Site URL** 에 `https://gcastleclub-ops.github.io/tracker/` 를 넣어두세요.

## 5. 기존 데이터 옮기기

1. https://gcastleclub-ops.github.io/tracker/ 접속 → 로그인
2. 좌측 하단 **⬆ 백업 파일 불러오기**
3. `frontx_kpi_backup_20260724.json` 선택 → 확인

주차·담당자 단위로 Supabase에 업로드됩니다. 같은 주차·담당자 데이터는 백업 파일 내용으로 덮어써집니다.

옛 버전(담당자 구분이 없던 시절) 백업도 자동으로 `이전 데이터` 담당자로 이관됩니다.

---

## 데이터 구조

| 테이블 | 내용 |
|---|---|
| `app_config` | KPI 항목 정의, 등급 정의, 사이드바 제목 (항상 1행) |
| `agents` | 담당자 목록 (`id`, `name`, `sort_order`) |
| `week_entries` | 주차 × 담당자 실적. PK = (`week_key`, `agent_id`) |

`week_key` 형식은 `YYYY-MM-W` (예: `2026-07-2` = 2026년 7월 2주차). 주차 계산은 원본과 동일하게 **해당 월 1~7일 = 1주차, 8~14일 = 2주차 …** 방식입니다.

`week_entries`의 `items` / `grades` / `meta_inbound`는 JSONB입니다.

```jsonc
// items
{ "visit": {"val": 42, "note": ""}, "contract": {"val": 1, "note": "구로 호스텔 더 까미노"} }
// grades
{ "A": 0, "B": 6, "C": 25, "D": 5, "note": "" }
// meta_inbound
{ "inbound": 3, "phoneGuide": 3, "met": 1, "toMeet": 0, "note": "..." }
```

### 저장 방식

- 입력할 때마다 **해당 주차·담당자 1행만** upsert 합니다 (0.6초 디바운스).
- 그래서 A담당자가 3주차를 입력하는 동안 B담당자가 2주차를 입력해도 서로 덮어쓰지 않습니다.
- 저장에 실패하면 4초 뒤 자동 재시도하고, 사이드바 하단에 상태가 표시됩니다.
- `담당자 관리`에서 담당자를 삭제해도 `week_entries`의 실적은 남아 "전체" 합계에 계속 반영됩니다 (원본 앱 동작 그대로).

---

## 자주 겪는 문제

**로그인은 되는데 데이터가 안 보이고 저장도 안 될 때**
`schema.sql`의 RLS 정책 부분이 실행되지 않았을 가능성이 높습니다. SQL Editor에서 다시 한 번 전체 실행해 보세요.

**다른 사람 입력이 실시간으로 안 넘어올 때**
Supabase **Database → Replication** 에서 `week_entries`가 `supabase_realtime` 발행에 포함돼 있는지 확인하세요. (`schema.sql` 6번 항목이 이 작업을 합니다.)

**"⚠ 저장 실패"가 계속 뜰 때**
브라우저 개발자도구 콘솔(F12)의 에러 메시지를 확인하세요. 대부분 RLS 정책 누락이거나 로그인 세션 만료입니다. 로그아웃 후 다시 로그인하면 해결됩니다.

**월 무료 한도**
Supabase 무료 플랜은 DB 500MB. 이 앱은 주차×담당자당 수 KB 수준이라 수년치를 넣어도 여유롭습니다. 단, **7일 이상 아무 요청이 없으면 프로젝트가 일시정지**되니 주 1회 이상 사용하거나 대시보드에서 복구하면 됩니다.

---

## 백업

Supabase에 저장되더라도 좌측 하단 **⬇ 백업 파일로 내보내기**로 주기적으로 JSON을 받아두는 것을 권장합니다. 이 파일은 언제든 **⬆ 백업 파일 불러오기**로 되돌릴 수 있습니다.
