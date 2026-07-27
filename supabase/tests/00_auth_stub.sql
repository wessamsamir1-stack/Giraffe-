-- =============================================================================
-- Giraffe — بديل محلي لسكيما auth بتاعة سوبابيز
--
-- الملف ده **للتطوير والاختبار المحلي فقط**. ممنوع تشغيله على سوبابيز —
-- هناك السكيما دي موجودة أصلاً وبيديرها النظام.
--
-- الغرض: نقدر نصرّف ونختبر كل المهاجرات على بوستجرس عادي.
-- =============================================================================

create schema if not exists auth;

create table if not exists auth.users (
  id            uuid primary key default gen_random_uuid(),
  email         text unique,
  phone         text unique,
  created_at    timestamptz not null default now()
);

-- بديل auth.uid() — بيقرأ من متغيّر جلسة نضبطه في الاختبارات
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

create or replace function auth.role()
returns text
language sql
stable
as $$
  select coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), 'anon')
$$;

-- أدوار سوبابيز
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end
$$;

grant usage on schema public to anon, authenticated, service_role;
grant usage on schema auth   to anon, authenticated, service_role;
grant select on auth.users   to authenticated, service_role;


-- =============================================================================
-- بديل سكيما storage — محلي فقط
--
-- عشان نقدر نصرّف سياسات التخزين ونتأكد إنها سليمة نحوياً من غير سوبابيز.
-- =============================================================================
create schema if not exists storage;

create table if not exists storage.buckets (
  id                 text primary key,
  name               text not null,
  public             boolean not null default false,
  file_size_limit    bigint,
  allowed_mime_types text[],
  created_at         timestamptz not null default now()
);

create table if not exists storage.objects (
  id         uuid primary key default gen_random_uuid(),
  bucket_id  text not null references storage.buckets(id),
  name       text not null,
  owner      uuid,
  created_at timestamptz not null default now()
);

alter table storage.objects enable row level security;

create or replace function storage.foldername(name text)
returns text[]
language sql
immutable
as $$
  select string_to_array(name, '/')
$$;

grant usage on schema storage to anon, authenticated;
grant select, insert, update, delete on storage.objects to authenticated;
