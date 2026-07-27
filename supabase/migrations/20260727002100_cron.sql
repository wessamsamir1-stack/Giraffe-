-- =============================================================================
-- Giraffe — 21. جدولة المهام الدورية
--
-- المهام دي كانت مكتوبة كتعليق في ملف 13 — يعني كانت هتفضل تعليق.
-- والمشكلة إنها مش تحسينات، دي شروط لصحة المنتج:
--
--   • من غير فك الحجوزات، أي منتج اتقبل عليه عرض ومحصلش بيفضل مقفول
--     للأبد. المخزون بينزف بالتدريج ومحدش بيلاحظ.
--   • من غير نشر التقييمات المتأخرة، اللي قيّم وماتقيّمش بيفضل تقييمه
--     محجوب — يعني عاقبناه لأنه اتعامل مع حد ماردّش.
--   • من غير تحديث الإحصائيات، مستوى الثقة بيتجمّد على آخر صفقة.
--
-- الملف ده بيشغّلها فعلاً، وبيتعامل مع إن pg_cron مش موجود محلياً.
-- =============================================================================

do $$
begin
  -- الامتداد موجود على سوبابيز، ومش موجود في بوستجرس عادي.
  -- بنحاول، ولو مافيش بنسيب رسالة واضحة بدل ما التهجير كله يقع.
  begin
    create extension if not exists pg_cron;
  exception when others then
    raise notice
      'pg_cron مش متاح هنا — الجدولة اتخطت. المهام نفسها موجودة وبتتنادى في الاختبارات.';
    return;
  end;

  -- ---------------------------------------------------------------------------
  -- إعادة الجدولة آمنة: بنشيل القديم الأول عشان التهجير يعيد تشغيله
  -- من غير ما يكرر المهام.
  -- ---------------------------------------------------------------------------
  perform cron.unschedule(jobname)
     from cron.job
    where jobname in (
      'giraffe-release-reservations',
      'giraffe-archive-stale',
      'giraffe-publish-reviews',
      'giraffe-refresh-stats',
      'giraffe-purge-limits',
      'giraffe-purge-ai-jobs'
    );

  -- ---------------------------------------------------------------------------
  -- كل ربع ساعة: فك الحجوزات المنتهية
  --
  -- الحجز 48 ساعة. ربع ساعة تأخير مقبول، والأقل من كده بيحمّل القاعدة
  -- من غير فايدة حقيقية للمستخدم.
  -- ---------------------------------------------------------------------------
  perform cron.schedule(
    'giraffe-release-reservations', '*/15 * * * *',
    $job$ select public.release_expired_reservations() $job$);

  -- ---------------------------------------------------------------------------
  -- المهام اليومية بالليل — بتوقيت القاهرة، والخادم بـ UTC
  --
  -- التوقيت الصيفي في مصر بيزحزح الساعات دي ساعة. مش فارقة لمهمة
  -- تنظيف، وكتابتها بـ UTC أوضح من التظاهر إننا بنتعامل مع المناطق.
  -- ---------------------------------------------------------------------------
  perform cron.schedule(
    'giraffe-archive-stale', '0 1 * * *',        -- 3 صباحاً بالقاهرة
    $job$ select public.archive_stale_matches() $job$);

  perform cron.schedule(
    'giraffe-publish-reviews', '0 2 * * *',
    $job$ select public.publish_due_reviews() $job$);

  perform cron.schedule(
    'giraffe-purge-limits', '30 1 * * *',
    $job$ select public.purge_old_daily_limits() $job$);

  -- ---------------------------------------------------------------------------
  -- كل ساعة: تحديث الإحصائيات على دفعات
  --
  -- على دفعات مش كلها مرة واحدة — عشان المهمة تفضل قصيرة مهما كبرت
  -- قاعدة المستخدمين. ولو الدفعة اتأخرت، اللي بعدها بتكمّل من نفس المكان.
  -- ---------------------------------------------------------------------------
  perform cron.schedule(
    'giraffe-refresh-stats', '0 * * * *',
    $job$ select public.refresh_stale_stats(500) $job$);

  -- ---------------------------------------------------------------------------
  -- تنظيف سجل مهام الذكاء الاصطناعي — 90 يوم
  --
  -- السجل ده بيكبر بسرعة (صف لكل رفع منتج) وقيمته بتنتهي بعد ما
  -- نراجع التكلفة. الاحتفاظ بيه للأبد تكلفة تخزين مقابل صفر فايدة.
  -- ---------------------------------------------------------------------------
  perform cron.schedule(
    'giraffe-purge-ai-jobs', '15 2 * * *',
    $job$ delete from public.ai_jobs where created_at < now() - interval '90 days' $job$);

  raise notice 'الجدولة اتفعّلت — 6 مهام دورية.';
end $$;


-- -----------------------------------------------------------------------------
-- لوحة متابعة الجدولة
--
-- مهمة مجدولة بتفشل في صمت أسوأ من مهمة مش مجدولة: إحنا فاكرين إنها
-- شغالة. الرؤية دي بتخلي الفشل ظاهر.
-- -----------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    execute $view$
      create or replace view public.cron_health as
      select j.jobname,
             j.schedule,
             j.active,
             r.status       as last_status,
             r.start_time   as last_run,
             r.return_message
        from cron.job j
        left join lateral (
          select status, start_time, return_message
            from cron.job_run_details d
           where d.jobid = j.jobid
           order by d.start_time desc
           limit 1
        ) r on true
       where j.jobname like 'giraffe-%'
    $view$;

    revoke all on public.cron_health from anon, authenticated;
  end if;
end $$;
