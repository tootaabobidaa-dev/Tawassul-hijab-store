-- ==========================================================
-- تنبيهات الطلبات الجديدة على هاتف الأدمن (Web Push)
-- نفّذ هذا الملف مرة واحدة من: Supabase → SQL Editor → New query → Run
-- ==========================================================

-- 1) جدول أجهزة الأدمن المشتركة في التنبيهات
create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  endpoint text unique not null,
  p256dh text not null,
  auth text not null,
  user_agent text,
  created_at timestamptz default now()
);

alter table public.push_subscriptions enable row level security;

drop policy if exists "admins manage own push subscriptions" on public.push_subscriptions;
create policy "admins manage own push subscriptions"
  on public.push_subscriptions
  for all
  to authenticated
  using (
    user_id = auth.uid()
    and exists (select 1 from public.admins a where a.user_id = auth.uid() and a.active = true)
  )
  with check (
    user_id = auth.uid()
    and exists (select 1 from public.admins a where a.user_id = auth.uid() and a.active = true)
  );

-- 2) استدعاء الدالة (Edge Function) تلقائيًا عند كل طلب جديد
create extension if not exists pg_net with schema extensions;

create or replace function public.notify_new_order()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  begin
    perform net.http_post(
      url := 'https://clxdpdwbysqaitzgfptl.supabase.co/functions/v1/notify-new-order',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-webhook-secret', 'ff5832654e48d550cb96030c37ac4abf0907d0dca53e5f19'
      ),
      body := jsonb_build_object('record', to_jsonb(new))
    );
  exception when others then
    null; -- لا نمنع تسجيل الطلب إذا فشل إرسال التنبيه
  end;
  return new;
end;
$$;

drop trigger if exists trg_notify_new_order on public.orders;
create trigger trg_notify_new_order
  after insert on public.orders
  for each row execute function public.notify_new_order();
