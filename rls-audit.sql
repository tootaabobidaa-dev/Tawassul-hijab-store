-- ١) للقراءة فقط — لا يغيّر شيئًا. نفّذي كل استعلام على حدة في Supabase > SQL Editor وأرسلي لي النتائج.

-- هل RLS مفعّل على كل جدول؟
select c.relname as table_name, c.relrowsecurity as rls_enabled
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r'
order by 1;

-- كل السياسات الحالية (ابحثي عن سياسات مفتوحة مثل using (true))
select schemaname, tablename, policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname in ('public','storage')
order by schemaname, tablename, policyname;

-- هل الدوال تعمل بصلاحية صاحبها؟ (security_definer = true)
select p.proname as function_name, p.prosecdef as security_definer
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('create_order','get_my_orders','register_customer_push','touch_last_seen','mark_offline','admin_delete_customer','admin_user_activity')
order by 1;

-- أعمدة الجداول المهمة
select table_name, column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name in ('admins','customers','orders','order_items','push_subscriptions','products','categories')
order by table_name, ordinal_position;
