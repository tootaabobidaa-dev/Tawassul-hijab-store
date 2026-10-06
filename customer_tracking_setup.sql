-- ==========================================================
-- تتبع حالة الطلب للعميلة + إشعار "موظف التوصيل في طريقه إليكِ"
-- نفّذ مرة واحدة من: Supabase → SQL Editor → New query → Run
-- ==========================================================

-- 1) ربط كل طلب بحساب العميلة التي أنشأته
alter table public.orders add column if not exists auth_user_id uuid references auth.users(id) on delete set null;

create or replace function public.set_order_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.auth_user_id is null then
    new.auth_user_id := auth.uid();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_set_order_auth_user on public.orders;
create trigger trg_set_order_auth_user
  before insert on public.orders
  for each row execute function public.set_order_auth_user();

-- ربط الطلبات القديمة بحسابات العميلات (بالبريد أو الهاتف) إن أمكن
do $$
begin
  update public.orders o
  set auth_user_id = c.auth_user_id
  from public.customers c
  where o.auth_user_id is null
    and c.auth_user_id is not null
    and ((c.email is not null and lower(c.email) = lower(o.customer_email))
      or (c.phone is not null and c.phone = o.customer_phone));
exception when others then
  null;
end $$;

-- 2) قراءة العميلة لطلباتها فقط (آمنة)
create or replace function public.get_my_orders()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', o.id,
      'order_number', o.order_number,
      'status', o.status,
      'total', o.total,
      'created_at', o.created_at,
      'order_items', (
        select coalesce(jsonb_agg(to_jsonb(i)), '[]'::jsonb)
        from public.order_items i where i.order_id = o.id
      )
    ) order by o.created_at desc
  ), '[]'::jsonb)
  from public.orders o
  where o.auth_user_id = auth.uid();
$$;

revoke all on function public.get_my_orders() from public, anon;
grant execute on function public.get_my_orders() to authenticated;

-- 3) أجهزة العميلات المشتركة في الإشعارات
create table if not exists public.customer_push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  endpoint text unique not null,
  p256dh text not null,
  auth text not null,
  user_agent text,
  created_at timestamptz default now()
);
alter table public.customer_push_subscriptions enable row level security;

create or replace function public.register_customer_push(p_endpoint text, p_p256dh text, p_auth text, p_ua text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  insert into public.customer_push_subscriptions(user_id, endpoint, p256dh, auth, user_agent)
  values (auth.uid(), p_endpoint, p_p256dh, p_auth, p_ua)
  on conflict (endpoint) do update
    set user_id = excluded.user_id, p256dh = excluded.p256dh, auth = excluded.auth, user_agent = excluded.user_agent;
end;
$$;

revoke all on function public.register_customer_push(text, text, text, text) from public, anon;
grant execute on function public.register_customer_push(text, text, text, text) to authenticated;

-- 4) عند تغيّر حالة الطلب نستدعي الدالة لإرسال الإشعار للعميلة
create extension if not exists pg_net with schema extensions;

create or replace function public.notify_order_status()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if new.status is distinct from old.status then
    begin
      perform net.http_post(
        url := 'https://clxdpdwbysqaitzgfptl.supabase.co/functions/v1/smooth-handler',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-webhook-secret', 'ff5832654e48d550cb96030c37ac4abf0907d0dca53e5f19'
        ),
        body := jsonb_build_object('event', 'status_changed', 'record', to_jsonb(new), 'old_status', old.status)
      );
    exception when others then
      null;
    end;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_order_status on public.orders;
create trigger trg_notify_order_status
  after update of status on public.orders
  for each row execute function public.notify_order_status();
