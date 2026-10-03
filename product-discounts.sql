-- نفّذي هذا الملف مرة واحدة في Supabase > SQL Editor
-- يضيف عمود "السعر قبل الخصم" لجدول المنتجات (قسم عروض التخفيضات يعتمد عليه)
alter table public.products add column if not exists old_price numeric;
