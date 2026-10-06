-- ٢) سياسات RLS وأدوار المشرفة — نفّذيه بعد إرسال نتائج rls-audit.sql ومراجعتي لها.
--    صُمّم ليتجنب كسر المتجر: كل جدول غير مؤكد البنية محميّ بفحص ويُتخطّى مع ملاحظة بدل أن يفشل.
--    تنبيه: السياسات في Postgres تُجمَع (أي سياسة تسمح = يسمح). لذلك احذفي يدويًا أي سياسة قديمة
--    مفتوحة (using true) تظهر في نتائج التدقيق، وإلا ستبقى الثغرة.

-- ===== دالة الدور: هل المستخدمة مشرفة نشطة؟ (وتتطلب المصادقة الثنائية aal2 إن كانت مفعّلة لحسابها) =====
create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (select 1 from public.admins a where a.user_id = auth.uid() and a.active)
     and ( coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2'
           or not exists (select 1 from auth.mfa_factors f where f.user_id = auth.uid() and f.status = 'verified') );
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

-- ===== admins: تقرأ المشرفة صفّها فقط، ولا كتابة من المتصفح =====
alter table public.admins enable row level security;
drop policy if exists admins_select_own on public.admins;
create policy admins_select_own on public.admins for select to authenticated using (user_id = auth.uid());

-- ===== products: الزوّار يقرؤون المنتجات الظاهرة فقط، والمشرفة تدير كل شيء =====
alter table public.products enable row level security;
drop policy if exists products_public_read on public.products;
create policy products_public_read on public.products for select to anon, authenticated using (active = true);
drop policy if exists products_admin_all on public.products;
create policy products_admin_all on public.products for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ===== categories =====
alter table public.categories enable row level security;
drop policy if exists categories_public_read on public.categories;
create policy categories_public_read on public.categories for select to anon, authenticated using (true);
drop policy if exists categories_admin_all on public.categories;
create policy categories_admin_all on public.categories for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ===== orders و order_items: لا وصول مباشر للعميلات، الطلبات عبر create_order / get_my_orders فقط =====
do $$
declare ok boolean;
begin
  select bool_and(p.prosecdef) and count(*) = 2 into ok
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname in ('create_order','get_my_orders');
  if coalesce(ok,false) then
    execute 'alter table public.orders enable row level security';
    execute 'alter table public.order_items enable row level security';
    execute 'drop policy if exists orders_admin_all on public.orders';
    execute 'create policy orders_admin_all on public.orders for all to authenticated using (public.is_admin()) with check (public.is_admin())';
    execute 'drop policy if exists order_items_admin_all on public.order_items';
    execute 'create policy order_items_admin_all on public.order_items for all to authenticated using (public.is_admin()) with check (public.is_admin())';
  else
    raise notice 'تخطّيت orders/order_items: create_order أو get_my_orders ليست security definer. أرسلي لي نتائج التدقيق.';
  end if;
end $$;

-- ===== customers: كل عميلة ترى وتعدّل صفّها فقط (إن كان فيه عمود user_id) =====
do $$
begin
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='customers' and column_name='user_id') then
    execute 'alter table public.customers enable row level security';
    execute 'drop policy if exists customers_own on public.customers';
    execute 'create policy customers_own on public.customers for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid())';
    execute 'drop policy if exists customers_admin_all on public.customers';
    execute 'create policy customers_admin_all on public.customers for all to authenticated using (public.is_admin()) with check (public.is_admin())';
  else
    raise notice 'تخطّيت customers: لا يوجد عمود user_id. أرسلي لي أعمدة الجدول.';
  end if;
end $$;

-- ===== push_subscriptions: للمشرفة فقط (العميلات يسجّلن عبر register_customer_push) =====
do $$
declare ok boolean;
begin
  select coalesce(bool_and(p.prosecdef), false) into ok
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'register_customer_push';
  if ok then
    execute 'alter table public.push_subscriptions enable row level security';
    execute 'drop policy if exists push_admin_all on public.push_subscriptions';
    execute 'create policy push_admin_all on public.push_subscriptions for all to authenticated using (public.is_admin()) with check (public.is_admin())';
  else
    raise notice 'تخطّيت push_subscriptions: register_customer_push ليست security definer.';
  end if;
end $$;

-- ===== التخزين (Storage) =====
-- صور المنتجات: قراءة عامة، والرفع/التعديل/الحذف للمشرفة فقط (يستبدل سياسة الرفع المفتوحة لأي مستخدمة مسجّلة)
drop policy if exists "upload product images" on storage.objects;
drop policy if exists product_images_public_read on storage.objects;
create policy product_images_public_read on storage.objects for select to anon, authenticated using (bucket_id = 'product-images');
drop policy if exists product_images_admin_write on storage.objects;
create policy product_images_admin_write on storage.objects for all to authenticated
  using (bucket_id = 'product-images' and public.is_admin()) with check (bucket_id = 'product-images' and public.is_admin());

-- إيصالات الدفع (خاصة): ترفع العميلة داخل مجلدها فقط، وتقرؤها هي أو المشرفة
drop policy if exists receipts_insert_own on storage.objects;
create policy receipts_insert_own on storage.objects for insert to authenticated
  with check (bucket_id = 'payment-receipts' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists receipts_select_own_or_admin on storage.objects;
create policy receipts_select_own_or_admin on storage.objects for select to authenticated
  using (bucket_id = 'payment-receipts' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));
