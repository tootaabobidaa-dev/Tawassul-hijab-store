-- ==========================================================
-- تقارير المبيعات: تسجيل تاريخ التسليم تلقائياً
-- نفّذ مرة واحدة من: Supabase → SQL Editor → New query → Run
-- (التقارير تعمل بدونه، لكنه يجعل تاريخ التسليم دقيقاً.)
-- ==========================================================
alter table public.orders add column if not exists delivered_at timestamptz;

create or replace function public.set_delivered_at()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'delivered' then
    if tg_op = 'INSERT' or old.status is distinct from 'delivered' then
      new.delivered_at := now();
    end if;
  else
    new.delivered_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_set_delivered_at on public.orders;
create trigger trg_set_delivered_at
  before insert or update of status on public.orders
  for each row execute function public.set_delivered_at();

-- الطلبات المسلّمة سابقاً: نستخدم تاريخ إنشائها كتاريخ تسليم تقريبي
update public.orders set delivered_at = created_at
where status = 'delivered' and delivered_at is null;
