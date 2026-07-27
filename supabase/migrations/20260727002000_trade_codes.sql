-- =============================================================================
-- Giraffe — 20. كود الإتمام لمرة واحدة
--
-- الشكل القديم كان:
--
--     'GRF-' || substring(match_id, 1, 8)
--
-- والمشكلة إن **الطرفين عندهم رقم الغرفة**. يعني كل واحد يقدر يحسب كود
-- التاني وهو قاعد في بيته. المسح الضوئي كان تمثيل — مابيثبتش إن حد
-- قابل حد.
--
-- والتأكيد نفسه كان بيتكتب من العميل مباشرةً على الجدول: صف بكود
-- من اختراعه و confirmed_at من ساعته هو.
--
-- ده مهم لأن مستوى الثقة كله مبني على عدد الصفقات المكتملة. حسابين
-- متعاونين كانوا يقدروا يوصلوا لأعلى مستوى ثقة في دقيقة، من غير ما
-- يتقايضوا ولا مرة — وبعدين يستعملوا الثقة دي على ناس حقيقيين.
--
-- الشكل الجديد:
--
--   1. الخادم بيولّد كود عشوائي لكل طرف.
--   2. **مسح كود التاني هو اللي بيأكد جهتي أنا.**
--      يعني مستحيل أأكد من غير ما أبقى شايف شاشة التاني.
--   3. العميل مابيكتبش على الجدول خالص — الدالة بس.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- عدّاد المحاولات — الكود 8 خانات، بس ده مش سبب نسيب التخمين مفتوح
-- -----------------------------------------------------------------------------
alter table public.trade_confirmations
  add column if not exists attempts     smallint not null default 0,
  add column if not exists issued_at    timestamptz not null default now(),
  add column if not exists confirmed_by uuid references public.profiles(id);

comment on column public.trade_confirmations.confirmed_by is
  'مين مسح الكود ده. لازم يكون الطرف التاني — الدالة بتفرض ده.';

-- الكود لازم يكون فريد داخل الغرفة، وإلا المسح بيبقى ملخبط
create unique index if not exists trade_confirmations_code_idx
  on public.trade_confirmations (match_id, code);


-- -----------------------------------------------------------------------------
-- توليد الكود
--
-- أبجدية من غير الحروف والأرقام اللي بتتلخبط في القراءة:
-- شلنا 0 و O و 1 و I و L — لأن الكود بيتقرا بالعين لما الكاميرا تفشل.
-- -----------------------------------------------------------------------------
create or replace function public.gen_trade_code()
returns text
language plpgsql
volatile
set search_path = public
as $$
declare
  alphabet constant text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  -- gen_random_uuid مصدره pg_strong_random — مش random() اللي بتتبع بذرة
  -- متوقّعة. ودي دالة أساسية في بوستجرس، مش من امتداد في سكيما تانية،
  -- فبتشتغل محلياً وعلى سوبابيز من غير فرق.
  hex constant text := replace(public.gen_random_uuid()::text, '-', '');
  out text := '';
  i int;
begin
  for i in 0..7 loop
    -- كل خانتين ست عشري = بايت. الانحياز من القسمة على 31 مهمل هنا:
    -- إحنا بنمنع التخمين بسقف المحاولات، مش بتوزيع مثالي.
    out := out || substr(
      alphabet,
      1 + (('x' || substr(hex, i * 2 + 1, 2))::bit(8)::int % length(alphabet)),
      1
    );
  end loop;
  return out;
end;
$$;


-- -----------------------------------------------------------------------------
-- إصدار كودي أنا
--
-- بترجع نفس الكود لو اتنادت تاني — عشان لو المستخدم قفل الشاشة وفتحها
-- مايتغيرش الكود اللي الطرف التاني بيحاول يمسحه.
-- -----------------------------------------------------------------------------
create or replace function public.issue_trade_code(p_match uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  me       uuid := auth.uid();
  m        public.matches;
  existing text;
  fresh    text;
  tries    int := 0;
begin
  if me is null then
    raise exception 'auth_required' using errcode = '28000';
  end if;

  select * into m from public.matches where id = p_match;

  if m is null or (m.user_a <> me and m.user_b <> me) then
    raise exception 'not_a_member' using errcode = '42501';
  end if;

  -- غرفة مقفولة أو محظورة مالهاش إتمام
  if m.closed_by_block or m.stage in ('cancelled', 'completed') then
    raise exception 'room_closed' using errcode = '42501';
  end if;

  select code into existing
    from public.trade_confirmations
   where match_id = p_match and user_id = me;

  if existing is not null then
    return existing;
  end if;

  -- التصادم شبه مستحيل، بس بنتعامل معاه بدل ما نفترض إنه مش هيحصل
  loop
    fresh := public.gen_trade_code();
    tries := tries + 1;
    exit when not exists (
      select 1 from public.trade_confirmations
       where match_id = p_match and code = fresh
    ) or tries > 8;
  end loop;

  insert into public.trade_confirmations (match_id, user_id, code)
  values (p_match, me, fresh);

  return fresh;
end;
$$;


-- -----------------------------------------------------------------------------
-- التأكيد بمسح كود الطرف التاني
--
-- القاعدة الحاكمة في سطر واحد:
--
--   الكود اللي بمسحه بتاع التاني، واللي بيتأكد هو **صفي أنا**.
--
-- عشان كده مستحيل أأكد لوحدي: لازم أكون شايف شاشته.
-- -----------------------------------------------------------------------------
create or replace function public.confirm_trade(p_match uuid, p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  me      uuid := auth.uid();
  m       public.matches;
  target  public.trade_confirmations;
  mine    public.trade_confirmations;
  norm    text := upper(regexp_replace(coalesce(p_code, ''), '[^0-9A-Za-z]', '', 'g'));
begin
  if me is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;

  select * into m from public.matches where id = p_match;

  if m is null or (m.user_a <> me and m.user_b <> me) then
    return jsonb_build_object('ok', false, 'error', 'not_a_member');
  end if;

  if m.closed_by_block or m.stage in ('cancelled', 'completed') then
    return jsonb_build_object('ok', false, 'error', 'room_closed');
  end if;

  -- لازم أكون أصدرت كودي الأول — يعني فتحت الشاشة وأنا موجود
  select * into mine
    from public.trade_confirmations
   where match_id = p_match and user_id = me;

  if mine is null then
    return jsonb_build_object('ok', false, 'error', 'issue_code_first');
  end if;

  if mine.confirmed_at is not null then
    return jsonb_build_object('ok', true, 'already', true);
  end if;

  -- -------------------------------------------------------------------------
  -- سقف المحاولات — 5 وبعدين الغرفة تتقفل على التأكيد
  --
  -- 8 خانات من 31 حرف يعني ~10^12 احتمال، والتخمين مش واقعي أصلاً.
  -- بس السقف بيمنع السيناريو التاني: بوت بيجرب على آلاف الغرف بالتوازي.
  -- -------------------------------------------------------------------------
  if mine.attempts >= 5 then
    return jsonb_build_object('ok', false, 'error', 'too_many_attempts');
  end if;

  select * into target
    from public.trade_confirmations
   where match_id = p_match
     and code = norm
     and user_id <> me;          -- ← مسح كودي أنا مابيعملش حاجة

  if target is null then
    update public.trade_confirmations
       set attempts = attempts + 1
     where match_id = p_match and user_id = me;

    return jsonb_build_object(
      'ok', false,
      'error', 'invalid_code',
      'attempts_left', 5 - (mine.attempts + 1)
    );
  end if;

  update public.trade_confirmations
     set confirmed_at = now(),
         confirmed_by = target.user_id,
         attempts = 0
   where match_id = p_match and user_id = me;

  -- المحفّز بيكمّل الصفقة لما الاتنين يأكدوا
  return jsonb_build_object(
    'ok', true,
    'completed', (
      select count(*) filter (where confirmed_at is not null) = 2
        from public.trade_confirmations where match_id = p_match
    )
  );
end;
$$;


-- =============================================================================
-- وقفل الباب: العميل مابيكتبش على جدول التأكيدات خالص
--
-- من غير السطرين دول، كل اللي فوق زينة — العميل هيفضل يقدر يعمل
-- upsert بصف مؤكد زي ما كان بيعمل بالظبط.
-- =============================================================================
revoke insert, update, delete on public.trade_confirmations from authenticated;

drop policy if exists confirmations_own on public.trade_confirmations;

-- القراءة بس هي اللي فضلت — والدوال فوق هي الطريق الوحيد للكتابة
comment on table public.trade_confirmations is
  'الكتابة من issue_trade_code و confirm_trade بس. العميل قراءة فقط.';

-- ومسح الكود مايوصلش للطرف التاني: كل واحد بيشوف كوده هو
drop policy if exists confirmations_members on public.trade_confirmations;

create policy confirmations_own_read on public.trade_confirmations
  for select using (user_id = auth.uid());

-- بس محتاج يعرف إن التاني أكّد ولا لأ — من غير ما يشوف كوده
create or replace function public.other_side_confirmed(p_match uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.trade_confirmations tc
      join public.matches m on m.id = tc.match_id
     where tc.match_id = p_match
       and tc.user_id <> auth.uid()
       and tc.confirmed_at is not null
       and (m.user_a = auth.uid() or m.user_b = auth.uid())
  );
$$;
