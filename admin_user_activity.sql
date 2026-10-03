-- نفّذي هذا الملف مرة واحدة في Supabase: SQL Editor ثم Run
-- يفترض أن customers.id هو نفسه معرّف حساب الدخول (auth.users.id)

-- 1) عمود آخر ظهور للعميل
alter table public.customers add column if not exists last_seen_at timestamptz;

-- 2) المتجر يستدعيها كل دقيقة لتسجيل أن العميل متصل
create or replace function public.touch_last_seen()
returns void
language sql
security definer
set search_path = public
as $$
  update public.customers set last_seen_at = now() where id = auth.uid();
$$;
revoke all on function public.touch_last_seen() from public, anon;
grant execute on function public.touch_last_seen() to authenticated;

-- 3) لوحة التحكم تقرأ النشاط (للمشرفات النشطات فقط)
create or replace function public.admin_user_activity()
returns table (
  customer_id uuid,
  last_sign_in_at timestamptz,
  last_seen_at timestamptz,
  active_sessions int,
  last_user_agent text
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not exists (
    select 1 from public.admins a where a.user_id = auth.uid() and a.active
  ) then
    raise exception 'not allowed';
  end if;

  return query
  select
    c.id,
    u.last_sign_in_at,
    c.last_seen_at,
    (select count(*)::int from auth.sessions s where s.user_id = u.id),
    (select s.user_agent from auth.sessions s where s.user_id = u.id order by s.created_at desc limit 1)
  from public.customers c
  left join auth.users u on u.id = c.id;
end;
$$;
revoke all on function public.admin_user_activity() from public, anon;
grant execute on function public.admin_user_activity() to authenticated;
