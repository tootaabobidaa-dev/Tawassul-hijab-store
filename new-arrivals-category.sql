-- نفّذي هذا الملف مرة واحدة في Supabase > SQL Editor
-- يضيف فئة "وصل حديثًا" لتختاريها عند إضافة/تعديل منتج
insert into public.categories (name)
select 'وصل حديثًا'
where not exists (select 1 from public.categories where name = 'وصل حديثًا');
