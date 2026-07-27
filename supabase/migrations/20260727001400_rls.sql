-- =============================================================================
-- Giraffe — 14. سياسات الحماية على مستوى الصف
--
-- القاعدة الحاكمة: **RLS مفعّل على كل جدول بدون استثناء**.
-- أي جدول جديد يتضاف من غير سياسة = تسريب بيانات.
--
-- ملاحظة مهمة: الدوال اللي بتُستخدم جوه السياسات لازم تكون
-- security definer عشان ماتدخلش في تكرار لا نهائي مع السياسات نفسها.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- الصلاحيات الأساسية
-- -----------------------------------------------------------------------------
grant usage on schema public to anon, authenticated;

grant select on
  public.countries, public.cities, public.areas,
  public.categories, public.subcategories, public.meeting_places
to anon, authenticated;

grant select, insert, update, delete on
  public.profiles, public.items, public.item_photos,
  public.item_wanted_categories, public.wishlist_items,
  public.swipes, public.matches, public.messages, public.offers,
  public.meetings, public.meeting_checklists, public.trade_confirmations,
  public.reviews, public.blocks, public.mutes, public.reports,
  public.disputes, public.emergency_contacts, public.push_tokens,
  public.notification_prefs, public.notifications, public.sos_alerts
to authenticated;

grant select on
  public.user_stats, public.daily_limits, public.wishlist_alerts,
  public.price_comparables
to authenticated;

grant usage, select on all sequences in schema public to authenticated;

-- -----------------------------------------------------------------------------
-- إخفاء درجة الترتيب على مستوى العمود
--
-- RLS بيشتغل على الصفوف مش الأعمدة، فبنستخدم صلاحيات الأعمدة.
-- ranking_score لازم يفضل مخفي تماماً — لو ظهر، هيتحول لهدف للتلاعب
-- ولمصدر لا ينتهي من الشكاوى.
-- -----------------------------------------------------------------------------
revoke select on public.user_stats from authenticated;
grant select (
  user_id, completed_trades, cancelled_trades, no_shows,
  completed_trades_90d, cancelled_trades_90d,
  rating_avg, rating_count, avg_response_minutes,
  trust_level, computed_at
) on public.user_stats to authenticated;


-- =============================================================================
-- تفعيل RLS
-- =============================================================================
alter table public.countries              enable row level security;
alter table public.cities                 enable row level security;
alter table public.areas                  enable row level security;
alter table public.categories             enable row level security;
alter table public.subcategories          enable row level security;
alter table public.meeting_places         enable row level security;
alter table public.banned_terms           enable row level security;
alter table public.price_comparables      enable row level security;

alter table public.profiles               enable row level security;
alter table public.user_stats             enable row level security;
alter table public.emergency_contacts     enable row level security;
alter table public.sos_alerts             enable row level security;
alter table public.push_tokens            enable row level security;
alter table public.notification_prefs     enable row level security;
alter table public.daily_limits           enable row level security;
alter table public.security_events        enable row level security;

alter table public.items                  enable row level security;
alter table public.item_photos            enable row level security;
alter table public.item_wanted_categories enable row level security;

alter table public.wishlist_items         enable row level security;
alter table public.wishlist_alerts        enable row level security;

alter table public.swipes                 enable row level security;
alter table public.matches                enable row level security;
alter table public.messages               enable row level security;
alter table public.offers                 enable row level security;
alter table public.meetings               enable row level security;
alter table public.meeting_checklists     enable row level security;
alter table public.trade_confirmations    enable row level security;

alter table public.reviews                enable row level security;
alter table public.blocks                 enable row level security;
alter table public.mutes                  enable row level security;
alter table public.reports                enable row level security;
alter table public.disputes               enable row level security;
alter table public.notifications          enable row level security;


-- =============================================================================
-- الجداول المرجعية — قراءة عامة، والكتابة للإدارة بس
-- =============================================================================
create policy ref_read_countries      on public.countries      for select using (true);
create policy ref_read_cities         on public.cities         for select using (true);
create policy ref_read_areas          on public.areas          for select using (true);
create policy ref_read_categories     on public.categories     for select using (is_active);
create policy ref_read_subcategories  on public.subcategories  for select using (true);
create policy ref_read_places         on public.meeting_places for select using (is_active);
create policy ref_read_comparables    on public.price_comparables for select
  using (auth.uid() is not null);

-- المصطلحات المحظورة مش بتتقرا من العميل خالص — الفحص بيتم على الخادم.
-- مفيش سياسة select = مفيش وصول (RLS بيرفض افتراضياً).


-- =============================================================================
-- الملف الشخصي
-- =============================================================================
create policy profiles_read_public on public.profiles
  for select using (
    not is_banned
    and not public.blocked_between(auth.uid(), id)
  );

create policy profiles_read_own on public.profiles
  for select using (id = auth.uid());

create policy profiles_insert_own on public.profiles
  for insert with check (id = auth.uid());

create policy profiles_update_own on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

create policy stats_read_public on public.user_stats
  for select using (true);


-- =============================================================================
-- جهة الطوارئ — لصاحبها فقط، بدون أي استثناء
--
-- الرقم ده مايتشافش من أي مستخدم تاني مهما كان. ده وعد صريح للمستخدم
-- في واجهة التطبيق ولازم يتفرض في القاعدة مش في الكود بس.
-- =============================================================================
create policy emergency_own on public.emergency_contacts
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy sos_own on public.sos_alerts
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy push_tokens_own on public.push_tokens
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy notif_prefs_own on public.notification_prefs
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy daily_limits_own on public.daily_limits
  for select using (user_id = auth.uid());

create policy security_events_own on public.security_events
  for select using (user_id = auth.uid());


-- =============================================================================
-- المنتجات
-- =============================================================================
create policy items_read_public on public.items
  for select using (
    moderation = 'approved'
    and status in ('available', 'reserved', 'negotiating', 'traded')
    and not public.blocked_between(auth.uid(), owner_id)
  );

create policy items_read_own on public.items
  for select using (owner_id = auth.uid());

create policy items_insert_own on public.items
  for insert with check (owner_id = auth.uid());

create policy items_update_own on public.items
  for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy items_delete_own on public.items
  for delete using (owner_id = auth.uid());

-- الصور والأقسام المرغوبة بتتبع صلاحية المنتج نفسه
create policy item_photos_read on public.item_photos
  for select using (
    exists (select 1 from public.items i where i.id = item_id)
  );

create policy item_photos_write on public.item_photos
  for all using (
    exists (select 1 from public.items i
             where i.id = item_id and i.owner_id = auth.uid())
  )
  with check (
    exists (select 1 from public.items i
             where i.id = item_id and i.owner_id = auth.uid())
  );

create policy item_wanted_read on public.item_wanted_categories
  for select using (
    exists (select 1 from public.items i where i.id = item_id)
  );

create policy item_wanted_write on public.item_wanted_categories
  for all using (
    exists (select 1 from public.items i
             where i.id = item_id and i.owner_id = auth.uid())
  )
  with check (
    exists (select 1 from public.items i
             where i.id = item_id and i.owner_id = auth.uid())
  );


-- =============================================================================
-- قائمة الرغبات — خاصة تماماً
--
-- قائمة رغبات المستخدم بيانات تنافسية وحساسة: لو ظهرت، أي حد يقدر
-- يستغلها في التسعير أو التلاعب. الوصول ليها من الخادم بس عبر دوال
-- security definer.
-- =============================================================================
create policy wishlist_own on public.wishlist_items
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy wishlist_alerts_own on public.wishlist_alerts
  for select using (user_id = auth.uid());


-- =============================================================================
-- السحبات — خاصة
--
-- "مين عمل لك إعجاب" ميزة مدفوعة في المرحلة التالتة، فالسحبات
-- مايتشافوش من الطرف التاني إطلاقاً على مستوى القاعدة.
-- =============================================================================
create policy swipes_own on public.swipes
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());


-- =============================================================================
-- غرفة المقايضة — للطرفين فقط
-- =============================================================================
create policy matches_members on public.matches
  for select using (user_a = auth.uid() or user_b = auth.uid());

create policy matches_update_members on public.matches
  for update using (user_a = auth.uid() or user_b = auth.uid())
  with check (user_a = auth.uid() or user_b = auth.uid());

-- الماتش بيتعمل من record_swipe (security definer) بس — مفيش إدراج مباشر.

create policy messages_read on public.messages
  for select using (public.is_match_member(match_id, auth.uid()));

-- ---------------------------------------------------------------------------
-- إرسال الرسائل: ممنوع في الغرف المقفولة بالحظر أو المجمّدة ببلاغ
--
-- ده تطبيق قاعدة "الحظر بيكسر كل القواعد التانية" على مستوى القاعدة،
-- مش على مستوى الواجهة — عشان ما ينفعش يتحايل عليه.
-- ---------------------------------------------------------------------------
create policy messages_send on public.messages
  for insert with check (
    sender_id = auth.uid()
    and public.is_match_member(match_id, auth.uid())
    and exists (
      select 1 from public.matches m
       where m.id = match_id
         and not m.closed_by_block
         and not m.frozen_by_report
         and m.stage not in ('completed', 'cancelled')
    )
  );

create policy messages_mark_read on public.messages
  for update using (
    public.is_match_member(match_id, auth.uid())
    and sender_id is distinct from auth.uid()
  )
  with check (public.is_match_member(match_id, auth.uid()));

create policy offers_read on public.offers
  for select using (public.is_match_member(match_id, auth.uid()));

create policy offers_create on public.offers
  for insert with check (
    from_user = auth.uid()
    and public.is_match_member(match_id, auth.uid())
    and exists (
      select 1 from public.matches m
       where m.id = match_id
         and not m.closed_by_block
         and not m.frozen_by_report
    )
  );

-- الرد على العرض: الطرف التاني بس هو اللي بيقبل أو يرفض
create policy offers_respond on public.offers
  for update using (
    public.is_match_member(match_id, auth.uid())
    and from_user <> auth.uid()
  )
  with check (public.is_match_member(match_id, auth.uid()));

create policy meetings_members on public.meetings
  for all using (public.is_match_member(match_id, auth.uid()))
  with check (public.is_match_member(match_id, auth.uid()));

create policy checklists_own on public.meeting_checklists
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy confirmations_members on public.trade_confirmations
  for select using (public.is_match_member(match_id, auth.uid()));

create policy confirmations_own on public.trade_confirmations
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());


-- =============================================================================
-- التقييمات
--
-- المنشور بس هو اللي بيتشاف — التقييم المحجوب مايتقراش حتى من صاحبه
-- المقيَّم، عشان نمنع الرد الانتقامي قبل النشر.
-- =============================================================================
create policy reviews_read_published on public.reviews
  for select using (published_at is not null);

create policy reviews_read_own on public.reviews
  for select using (reviewer_id = auth.uid());

create policy reviews_write on public.reviews
  for insert with check (
    reviewer_id = auth.uid()
    and public.is_match_member(match_id, auth.uid())
    and exists (
      select 1 from public.matches m
       where m.id = match_id and m.stage = 'completed'
    )
  );


-- =============================================================================
-- الحظر والكتم والبلاغات
-- =============================================================================
create policy blocks_own on public.blocks
  for all using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

create policy mutes_own on public.mutes
  for all using (muter_id = auth.uid()) with check (muter_id = auth.uid());

create policy reports_create on public.reports
  for insert with check (reporter_id = auth.uid());

create policy reports_read_own on public.reports
  for select using (reporter_id = auth.uid());

create policy disputes_create on public.disputes
  for insert with check (
    opened_by = auth.uid()
    and public.is_match_member(match_id, auth.uid())
  );

create policy disputes_read_members on public.disputes
  for select using (public.is_match_member(match_id, auth.uid()));


-- =============================================================================
-- الإشعارات
-- =============================================================================
create policy notifications_own on public.notifications
  for select using (user_id = auth.uid());

create policy notifications_mark_read on public.notifications
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());
