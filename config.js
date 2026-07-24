/* ============================================================
   Supabase 연결 정보
   Supabase Dashboard → Project Settings → API 에서 복사해 넣으세요.

   - url     : Project URL          (예: https://abcdefgh.supabase.co)
   - anonKey : anon / public key    ("service_role" 키는 절대 넣지 마세요!)

   anon key 는 브라우저에 공개되는 것이 정상입니다.
   실제 접근 통제는 schema.sql 의 RLS 정책 + 로그인이 담당합니다.
   ============================================================ */
window.SUPABASE_CONFIG = {
  url:     'https://gacjjukycdymqyfmregx.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdhY2pqdWt5Y2R5bXF5Zm1yZWd4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ4NzQwOTksImV4cCI6MjEwMDQ1MDA5OX0.uK-C8V0FEDhMWHP3Xr9lXnc0mtGKU7So5aytmF8uR7U'
};
