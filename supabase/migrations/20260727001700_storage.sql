-- =============================================================================
-- Giraffe — 17. دلاء التخزين وسياساتها
--
-- ثلاث دلاء بثلاث درجات وصول مختلفة:
--
--   avatars      عام القراءة   — صورة الملف الشخصي
--   item-photos  عام القراءة   — صور المنتجات
--   evidence     خاص تماماً    — مرفقات البلاغات والنزاعات
--
-- القاعدة الحاكمة في الكتابة: **مسار الملف لازم يبدأ برقم صاحبه**.
-- كده المستخدم مايقدرش يكتب ولا يمسح في مجلد حد تاني، والسياسة بتتأكد
-- من ده على مستوى التخزين مش على مستوى التطبيق.
-- =============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars',     'avatars',     true,  2 * 1024 * 1024,
   array['image/jpeg', 'image/png', 'image/webp']),
  ('item-photos', 'item-photos', true,  8 * 1024 * 1024,
   array['image/jpeg', 'image/png', 'image/webp']),
  -- مرفقات البلاغات خاصة: بتتعرض للإدارة فقط وبرابط موقّع قصير المدى
  ('evidence',    'evidence',    false, 8 * 1024 * 1024,
   array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public             = excluded.public,
  file_size_limit    = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;


-- -----------------------------------------------------------------------------
-- القراءة
-- -----------------------------------------------------------------------------
drop policy if exists storage_read_public on storage.objects;
create policy storage_read_public on storage.objects
  for select
  using (bucket_id in ('avatars', 'item-photos'));

drop policy if exists storage_read_own_evidence on storage.objects;
create policy storage_read_own_evidence on storage.objects
  for select
  using (
    bucket_id = 'evidence'
    and auth.uid() is not null
    and (storage.foldername(name))[1] = auth.uid()::text
  );


-- -----------------------------------------------------------------------------
-- الكتابة — المجلد الأول في المسار لازم يكون رقم المستخدم
-- -----------------------------------------------------------------------------
drop policy if exists storage_write_own on storage.objects;
create policy storage_write_own on storage.objects
  for insert
  with check (
    bucket_id in ('avatars', 'item-photos', 'evidence')
    and auth.uid() is not null
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists storage_update_own on storage.objects;
create policy storage_update_own on storage.objects
  for update
  using (
    auth.uid() is not null
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists storage_delete_own on storage.objects;
create policy storage_delete_own on storage.objects
  for delete
  using (
    auth.uid() is not null
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- -----------------------------------------------------------------------------
-- ملاحظة تشغيلية
--
-- الملفات دي **مش بتتحذف تلقائياً** لما المنتج يتمسح. لازم مهمة دورية
-- أو Edge Function تنضّف اليتيم منها، وإلا الفاتورة بتكبر بهدوء.
--
-- كمان: كل صورة بتتفحص قبل النشر (طبقة رخيصة ثم موديل قوي للمشكوك فيه)
-- والمنتج بيفضل `pending` لحد ما الفحص يعتمده — شوف items.moderation.
-- -----------------------------------------------------------------------------
