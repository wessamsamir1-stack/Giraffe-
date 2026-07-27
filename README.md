# Giraffe 🦒

**Swipe. Match. Trade.**

اسحب • تطابق • قايض

---

شبكة مقايضة اجتماعية — مش سوق إلكتروني ومش مزاد.

الناس ما بتتصفحش منتجات، الناس بتكتشف بعض من خلال الحاجات اللي بيملكوها.

الشات ما بيفتحش غير لما الطرفين يكونوا مهتمين ببعض فعلاً.

**الأسواق:** مصر · السعودية · الإمارات · الكويت · قطر · البحرين · عُمان

---

## الحالة الحالية — Current status

المرحلة: **تصميم مبدئي**

`Phase 0 — Design`

- ✅ وثائق المنتج كاملة
- ✅ تطبيق فلاتر بنظام تصميم كامل و**44 شاشة**
- ✅ سكيما قاعدة البيانات **مصرّفة ومختبَرة** — 33 جدول · 45 سياسة حماية
- ✅ محرك المطابقة بشرط الترشيح المزدوج — أكثر من 60 تأكيد ناجح
- ✅ طبقة بيانات كاملة + المسارات الأساسية مربوطة بسوبابيز
- ⬜ باقي الشاشات (المستودعات جاهزة — الناقص التوصيل)
- ⬜ دوال الحافة للذكاء الاصطناعي

الشاشات كلها شغالة وقابلة للتنقل ببيانات تجريبية.

**سوق الإطلاق: مصر — القاهرة الكبرى.**

---

## تشغيل التطبيق — Running the app

```bash
cd app
flutter pub get
flutter run
```

يتطلب

`Flutter 3.19`

أو أحدث.

**بيشتغل من غير أي مفاتيح** — كل البيانات تجريبية في

`lib/data/mock/`

للتشغيل على خادم حقيقي:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
```

التفاصيل في [`docs/09-app-integration.md`](docs/09-app-integration.md)

### الخطوط

المشروع بيستخدم خط النظام كبديل ويشتغل عادي.

للشكل النهائي، حمّل

`Inter`

و

`IBM Plex Sans Arabic`

وحطهم في

`app/assets/fonts/`

وشيل التعليق عن قسم الخطوط في

`app/pubspec.yaml`

---

## الوثائق — Documentation

| الملف | المحتوى |
|---|---|
| [`docs/01-mvp-scope.md`](docs/01-mvp-scope.md) | نطاق النسخة الأولى — إيه داخل وإيه بره وليه |
| [`docs/02-screen-map.md`](docs/02-screen-map.md) | خريطة الشاشات ومسارات التنقل |
| [`docs/03-roadmap.md`](docs/03-roadmap.md) | خطة التنفيذ على ٣ مراحل |
| [`docs/04-product-decisions.md`](docs/04-product-decisions.md) | القرارات المنتجية وأسبابها |
| [`docs/05-auth-security.md`](docs/05-auth-security.md) | تأمين التسجيل والدخول |
| [`docs/06-categories-and-markets.md`](docs/06-categories-and-markets.md) | الأقسام الـ 21 والأسواق السبعة |
| [`docs/07-design-system.md`](docs/07-design-system.md) | نظام التصميم والمكوّنات |
| [`docs/08-database.md`](docs/08-database.md) | قاعدة البيانات ومحرك المطابقة |
| [`docs/09-app-integration.md`](docs/09-app-integration.md) | ربط التطبيق بالخادم |

---

## بنية المشروع — Project structure

```
app/lib/
├── core/
│   ├── theme/        الألوان · الخطوط · الأبعاد · الثيم
│   ├── l10n/         الترجمة (عربي / إنجليزي)
│   ├── router/       كل المسارات
│   ├── security/     كلمة السر · المدققات · حارس المحاولات
│   └── app_state.dart
├── data/
│   ├── catalog/      الأقسام · الدول والعملات
│   ├── models/       نماذج البيانات
│   └── mock/         بيانات تجريبية (بتتشال عند الربط)
├── widgets/          مكتبة المكوّنات
└── features/
    ├── splash/  onboarding/  auth/  shell/
    ├── market/       السوق المفتوح
    ├── deck/         السحب
    ├── matches/      غرف المقايضة
    ├── items/        المنتجات وقائمة الرغبات
    ├── profile/  settings/  notifications/  safety/
```

---

## قاعدة البيانات — Database

```bash
# على سوبابيز
supabase db push

# محلياً: تصريف + أكثر من 60 اختبار
./supabase/tests/run_local.sh
```

```
supabase/
├── migrations/   17 ملف — الجداول والدوال والمحفّزات وسياسات الحماية
├── tests/        بديل سكيما auth + اختبارات الدخان
└── tools/        مولّد بذور الأقسام من كتالوج الدارت
```

التفاصيل في [`docs/08-database.md`](docs/08-database.md)

---

## الهوية — Brand

اللون الأساسي

`#F58220`

الخط الإنجليزي

`Inter`

الخط العربي

`IBM Plex Sans Arabic`

---

## المؤشر الرئيسي — North Star Metric

**عدد الصفقات المكتملة لكل مستخدم نشط شهرياً**

`Completed trades per monthly active user`

مش الـ

`DAU`

ولا الـ

`Match Rate`

المؤشران دول مضللان في منتج المقايضة.
