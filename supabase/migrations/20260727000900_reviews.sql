-- =============================================================================
-- Giraffe — 09. التقييمات
--
-- التقييم **محجوب** لحد ما الطرفين يقيّموا أو تعدي 7 أيام من الصفقة.
--
-- السبب: التقييم الانتقامي. لو شفت إنه قيّمني وحش هقيّمه وحش.
-- نفس نظام Airbnb وهو مجرّب وناجح.
-- =============================================================================

create table public.reviews (
  id            uuid primary key default gen_random_uuid(),
  match_id      uuid not null references public.matches(id) on delete cascade,
  reviewer_id   uuid not null references public.profiles(id) on delete cascade,
  reviewee_id   uuid not null references public.profiles(id) on delete cascade,

  overall       smallint not null check (overall between 1 and 5),
  accuracy      smallint check (accuracy between 1 and 5),
  punctuality   smallint check (punctuality between 1 and 5),
  comment       text check (char_length(comment) <= 400),

  -- null = لسه محجوب
  published_at  timestamptz,
  created_at    timestamptz not null default now(),

  constraint reviews_no_self check (reviewer_id <> reviewee_id),
  unique (match_id, reviewer_id)
);

create index reviews_reviewee_idx on public.reviews (reviewee_id, published_at desc)
  where published_at is not null;
create index reviews_pending_idx  on public.reviews (created_at)
  where published_at is null;

-- -----------------------------------------------------------------------------
-- نشر التقييم لما الطرفين يقيّموا
-- -----------------------------------------------------------------------------
create or replace function public.tg_publish_mutual_reviews()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  both_done boolean;
begin
  select count(*) >= 2 into both_done
    from public.reviews
   where match_id = new.match_id;

  if both_done then
    update public.reviews
       set published_at = now()
     where match_id = new.match_id
       and published_at is null;

    perform public.refresh_user_stats(r.reviewee_id)
       from (select distinct reviewee_id from public.reviews
              where match_id = new.match_id) r;
  end if;

  return new;
end;
$$;

create trigger reviews_publish_mutual
  after insert on public.reviews
  for each row execute function public.tg_publish_mutual_reviews();

-- -----------------------------------------------------------------------------
-- نشر التقييمات المتأخرة بعد 7 أيام
--
-- بتتنادى من مهمة مجدولة (pg_cron على سوبابيز، أو Edge Function).
-- بترجع عدد التقييمات اللي اتنشرت.
-- -----------------------------------------------------------------------------
create or replace function public.publish_due_reviews()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  affected int;
  r record;
begin
  with published as (
    update public.reviews
       set published_at = now()
     where published_at is null
       and created_at < now() - interval '7 days'
    returning reviewee_id
  )
  select count(*) into affected from published;

  for r in
    select distinct reviewee_id
      from public.reviews
     where published_at > now() - interval '1 minute'
  loop
    perform public.refresh_user_stats(r.reviewee_id);
  end loop;

  return affected;
end;
$$;

comment on function public.publish_due_reviews is
  'تُنادى يومياً. بتنشر التقييمات اللي عدى عليها 7 أيام من غير رد من الطرف التاني.';
