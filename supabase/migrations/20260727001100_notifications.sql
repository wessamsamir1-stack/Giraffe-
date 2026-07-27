-- =============================================================================
-- Giraffe — 11. الإشعارات
-- =============================================================================

create table public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  kind        public.notification_kind not null,
  title_ar    text not null,
  title_en    text not null,
  body_ar     text,
  body_en     text,
  -- بيانات التوجيه: {"match_id": "...", "item_id": "..."}
  payload     jsonb not null default '{}'::jsonb,
  read_at     timestamptz,
  created_at  timestamptz not null default now()
);

create index notifications_user_idx   on public.notifications (user_id, created_at desc);
create index notifications_unread_idx on public.notifications (user_id)
  where read_at is null;

-- -----------------------------------------------------------------------------
-- إرسال إشعار مع احترام تفضيلات المستخدم
-- -----------------------------------------------------------------------------
create or replace function public.notify_user(
  p_user      uuid,
  p_kind      public.notification_kind,
  p_title_ar  text,
  p_title_en  text,
  p_payload   jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  allowed boolean;
  new_id  uuid;
begin
  select case p_kind
           when 'match'    then matches
           when 'message'  then messages
           when 'offer'    then offers
           when 'wishlist' then wishlist
           when 'nearby'   then nearby
           else true
         end
    into allowed
    from public.notification_prefs
   where user_id = p_user;

  if coalesce(allowed, true) = false then
    return null;
  end if;

  insert into public.notifications (user_id, kind, title_ar, title_en, payload)
  values (p_user, p_kind, p_title_ar, p_title_en, p_payload)
  returning id into new_id;

  return new_id;
end;
$$;

-- -----------------------------------------------------------------------------
-- تنبيه أصحاب قوائم الرغبات لما منتج مطابق ينشر
--
-- بتتنادى بعد اعتماد المنتج. بترجع عدد الناس اللي اتنبهوا.
--
-- ملاحظة: بنستثني صاحب المنتج نفسه، والمحظورين في أي اتجاه، ومين
-- اتنبه على نفس المنتج قبل كده.
-- -----------------------------------------------------------------------------
create or replace function public.fanout_wishlist_alerts(p_item uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  it      public.items;
  sent    int := 0;
  target  record;
begin
  select * into it from public.items where id = p_item;
  if it is null or it.status <> 'available' then
    return 0;
  end if;

  for target in
    select distinct w.user_id, w.id as wish_id
      from public.wishlist_items w
      join public.profiles p on p.id = w.user_id
      join public.cities   c on c.id = p.city_id
      join public.cities   ic on ic.id = it.city_id
     where w.notify
       and w.user_id <> it.owner_id
       -- نفس السوق فقط — المقايضة عملية فيزيائية
       and c.market_group = ic.market_group
       and public.wishlist_match_score(w.user_id, it) >= 50
       and not public.blocked_between(w.user_id, it.owner_id)
       and not exists (
         select 1 from public.wishlist_alerts a
          where a.user_id = w.user_id and a.item_id = it.id
       )
  loop
    insert into public.wishlist_alerts (user_id, item_id, wish_id)
    values (target.user_id, it.id, target.wish_id)
    on conflict do nothing;

    perform public.notify_user(
      target.user_id,
      'wishlist',
      it.title || ' — من قائمة رغباتك',
      it.title || ' — from your wishlist',
      jsonb_build_object('item_id', it.id)
    );

    sent := sent + 1;
  end loop;

  return sent;
end;
$$;
