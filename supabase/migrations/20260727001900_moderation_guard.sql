-- =============================================================================
-- Giraffe — 19. حارس الفحص
--
-- من غير الملف ده، كل طبقة الفحص اللي بنيناها **قابلة للتخطي بسطر واحد**.
--
-- المستخدم عنده صلاحية update على منتجاته (وده لازم — بيعدّل عنوانه وسعره).
-- يعني أي حد يقدر ينادي الواجهة مباشرة ويكتب:
--
--     update items set status = 'available', moderation = 'approved'
--
-- وينشر أي حاجة من غير ما تعدّي على أي فحص. الحماية على مستوى الصف
-- بتقول «ده منتجك» — وهي محقة — لكنها مش بتقول «مش من حقك تعتمد نفسك».
--
-- الفرق بين الاتنين هو الملف ده.
--
-- وكمان بيقفل الباب التاني: تنشر حاجة بريئة، تعدّي الفحص، وبعدين تعدّل
-- العنوان لحاجة ممنوعة. أي تعديل جوهري بيرجّع المنتج للفحص من الأول.
-- =============================================================================

create or replace function public.tg_guard_item_moderation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- ---------------------------------------------------------------------------
  -- الخادم بينادي apply_moderation بمفتاح الخدمة، ووقتها auth.uid() بيبقى
  -- فاضي. ده الفرق الوحيد اللي بنعتمد عليه — ومابيتزوّرش من العميل، لأن
  -- الادعاء ده جاي من الرمز اللي سوبابيز نفسه بيتحقق منه.
  -- ---------------------------------------------------------------------------
  if auth.uid() is null then
    return new;
  end if;

  -- ---------------------------------------------------------------------------
  -- قرار الفحص ملكنا إحنا — المستخدم مايكتبش فيه ولا في سببه ولا في
  -- تاريخ النشر. بنرجّعهم لقيمهم القديمة بدل ما نرمي خطأ: التعديل
  -- المشروع في باقي الحقول بيعدّي عادي، والتلاعب بيتشال في صمت.
  -- ---------------------------------------------------------------------------
  new.moderation      := old.moderation;
  new.moderation_note := old.moderation_note;
  new.published_at    := old.published_at;

  -- ---------------------------------------------------------------------------
  -- أي تعديل جوهري على منتج معتمد بيرجّعه للفحص
  --
  -- الحقول دي بالذات هي اللي الفحص بيقرأها. تغييرها بعد الاعتماد
  -- معناه إن الاعتماد بقى على محتوى مابقاش موجود.
  -- ---------------------------------------------------------------------------
  if old.moderation = 'approved' and (
       new.title       is distinct from old.title
    or new.description is distinct from old.description
    or new.category_id is distinct from old.category_id
  ) then
    new.moderation   := 'pending';
    new.published_at := null;
    if new.status = 'available' then
      new.status := 'pending';
    end if;
  end if;

  -- ---------------------------------------------------------------------------
  -- ومهما حصل: مفيش منتج بيبقى متاح من غير اعتماد
  --
  -- ده السطر الأخير في الدفاع. حتى لو فات حاجة من اللي فوق، الشرط ده
  -- بيفضل صحيح دايماً.
  -- ---------------------------------------------------------------------------
  if new.status = 'available' and new.moderation <> 'approved' then
    new.status := 'pending';
  end if;

  return new;
end;
$$;

create trigger items_guard_moderation
  before update on public.items
  for each row execute function public.tg_guard_item_moderation();

-- -----------------------------------------------------------------------------
-- والإدخال كمان
--
-- مفيش فايدة من حراسة التعديل لو الإنشاء نفسه بيقدر يبدأ معتمد.
-- -----------------------------------------------------------------------------
create or replace function public.tg_guard_item_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return new;
  end if;

  new.moderation      := 'pending';
  new.moderation_note := null;
  new.published_at    := null;

  if new.status not in ('draft', 'pending') then
    new.status := 'pending';
  end if;

  return new;
end;
$$;

create trigger items_guard_insert
  before insert on public.items
  for each row execute function public.tg_guard_item_insert();

comment on function public.tg_guard_item_moderation() is
  'المستخدم مايعتمدش منتجه بنفسه. القرار من apply_moderation بس، '
  'وأي تعديل جوهري بعد الاعتماد بيرجّع المنتج للفحص.';


-- =============================================================================
-- والباب التالت: نداء دوال الفحص مباشرة
--
-- بوستجرس بيدي صلاحية التنفيذ لـ PUBLIC على أي دالة جديدة تلقائياً.
-- يعني الدوال دي — وكلها security definer — كانت متاحة لأي مستخدم مسجّل
-- ينفّذها من الواجهة على طول:
--
--     rpc('apply_moderation', { p_item: '...', p_result: 'approved' })
--
-- الحارس فوق بيوقف الضرر ده، لكن الاعتماد على طبقة واحدة غلط.
-- الدوال دي شغل خادم — نشيل صلاحيتها من الأساس.
-- =============================================================================
revoke execute on function public.apply_moderation(uuid, public.moderation_status, text)
  from public, anon, authenticated;

revoke execute on function public.learn_from_completed_trade(uuid)
  from public, anon, authenticated;

revoke execute on function public.ai_quota_check(uuid)
  from public, anon, authenticated;

revoke execute on function public.prescreen_item(uuid)
  from public, anon, authenticated;

-- التقدير كمان: مش سر، لكن نداؤه مباشرةً بيتخطى سقف التكلفة والتسجيل
revoke execute on function public.estimate_from_comparables(
  char, text, text, text, text, public.item_condition
) from public, anon, authenticated;
