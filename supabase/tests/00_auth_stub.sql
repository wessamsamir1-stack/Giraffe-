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
