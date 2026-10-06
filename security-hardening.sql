-- نفّذي هذا الملف مرة واحدة في Supabase > SQL Editor
-- يمنع التلاعب بسعر المنتج من المتصفح: سعر كل عنصر في الطلب يُؤخذ من جدول المنتجات وليس من العميلة.
-- (يعمل فقط إن كان لجدول order_items عمود unit_price؛ وإلا يعرض ملاحظة ولا يغيّر شيئًا.)

do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='order_items' and column_name='unit_price') then

    create or replace function public.enforce_order_item_price()
    returns trigger
    language plpgsql
    security definer
    set search_path = public
    as $f$
    declare p numeric;
    begin
      if new.quantity is null or new.quantity < 1 or new.quantity > 50 then
        raise exception 'كمية غير صالحة';
      end if;
      if new.product_id is not null then
        select price into p from public.products where id = new.product_id and active = true;
        if not found then
          raise exception 'المنتج غير متوفر';
        end if;
        new.unit_price := p;
      end if;
      return new;
    end;
    $f$;

    drop trigger if exists trg_enforce_order_item_price on public.order_items;
    create trigger trg_enforce_order_item_price
      before insert on public.order_items
      for each row execute function public.enforce_order_item_price();
  else
    raise notice 'لا يوجد عمود unit_price في order_items — أرسلي لي أسماء أعمدة الجدول لأكتب الحماية المناسبة.';
  end if;
end $$;
