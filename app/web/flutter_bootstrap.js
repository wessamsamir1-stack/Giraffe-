{{flutter_js}}
{{flutter_build_config}}

// قالب الإقلاع — فلاتر بيستبدل السطرين اللي فوق وقت البناء.
//
// ليه قالب خاص بدل الافتراضي:
//
// ١. عامل الخدمة (service worker): الافتراضي بيسجّل واحد بيخزّن
//    التطبيق كاش ويرد على الطلبات بدل السيرفر. النتيجة كانت إن أي
//    تحديث بننشره مابيوصلش، وحتى إعادة التحميل القسرية مابتنفعش.
//    هنا مش بنمرّر serviceWorkerSettings خالص، فمفيش تسجيل.
//
// ٢. الرسم جوّه #giraffe-host: عشان نبعد عن نوتش الآيفون والشرطة اللي
//    تحت (التفاصيل في index.html). لو العنصر مش موجود — زي صفحة المعاينة
//    جوّه Claude — فلاتر بيترسم في الصفحة كلها عادي.
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const host = document.querySelector('#giraffe-host');
    const appRunner = await engineInitializer.initializeEngine(
      host ? { hostElement: host } : {}
    );
    await appRunner.runApp();
  },
});
