-- نفّذي هذا الملف مرة واحدة في Supabase > SQL Editor
-- ينقص المخزون تلقائياً عند تحويل حالة الطلب إلى "تم التسليم" (delivered)

alter table public.orders add column if not exists stock_deducted boolean not null default false;

create or replace function public.deduct_stock_on_delivery()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- تم التسليم: خصم الكمية المباعة (مرة واحدة فقط لكل طلب)
  if new.status = 'delivered' and coalesce(old.stock_deducted,false) = false then
    update public.products p
       set stock = greatest(p.stock - s.qty, 0)
      from (select product_id, sum(quantity) as qty
              from public.order_items
             where order_id = new.id and product_id is not null
             group by product_id) s
     where p.id = s.product_id;
    new.stock_deducted := true;

  -- تصحيح الحالة بعد التسليم (إلغاء/تراجع): إعادة الكمية للمخزون
  elsif new.status <> 'delivered' and coalesce(old.stock_deducted,false) = true then
    update public.products p
       set stock = p.stock + s.qty
      from (select product_id, sum(quantity) as qty
              from public.order_items
             where order_id = new.id and product_id is not null
             group by product_id) s
     where p.id = s.product_id;
    new.stock_deducted := false;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_deduct_stock_on_delivery on public.orders;
create trigger trg_deduct_stock_on_delivery
  before update of status on public.orders
  for each row execute function public.deduct_stock_on_delivery();
