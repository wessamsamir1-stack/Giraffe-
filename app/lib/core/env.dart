/// إعدادات البيئة.
///
/// بتتحقن وقت البناء ومش بتتخزن في المستودع أبداً:
///
/// ```bash
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
/// ```
///
/// من غيرها التطبيق **بيشتغل عادي** على البيانات التجريبية — عشان أي حد
/// يقدر يفتح المشروع ويشوف كل الشاشات من غير ما يجهّز خادم.
class Env {
  const Env._();

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  /// هل الخادم متاح؟ لو لأ، التطبيق بيشتغل على `Mock`.
  static bool get hasBackend =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// مفتاح `anon` عام بطبيعته وآمن في التطبيق — الحماية الحقيقية من
  /// سياسات الصفوف في القاعدة مش من إخفاء المفتاح.
  ///
  /// أي مفتاح تاني (service role, OpenAI, بوابة الدفع) **ممنوع منعاً
  /// باتاً** يدخل التطبيق. كله من Edge Functions.
  static const bool serviceKeysNeverInClient = true;
}
