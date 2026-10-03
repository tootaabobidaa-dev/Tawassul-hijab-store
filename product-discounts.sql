-- نفّذي هذا الملف مرة واحدة في Supabase > SQL Editor
-- يضيف عمود "السعر قبل الخصم" لجدول المنتجات (قسم عروض التخفيضات يعتمد عليه)
alter table public.products add column if not exists old_price numeric;

-- إضافة فئة "عروض التخفيضات" لتظهر في قائمة الفئات عند إضافة/تعديل منتج
insert into public.categories (name)
select 'عروض التخفيضات'
where not exists (select 1 from public.categories where name = 'عروض التخفيضات');
