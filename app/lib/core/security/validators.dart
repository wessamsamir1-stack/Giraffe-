import '../../data/catalog/countries.dart';

/// مدققات الإدخال.
///
/// كل دالة بترجع مفتاح رسالة الخطأ أو `null` لو الإدخال سليم.
class Validators {
  const Validators._();

  static final RegExp _email = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );

  static final RegExp _username = RegExp(r'^[a-z0-9_]{3,20}$');

  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) return 'auth.err.emptyField';
    return null;
  }

  static String? email(String? value) {
    final empty = required(value);
    if (empty != null) return empty;
    final v = value!.trim();
    if (v.length > 254) return 'auth.err.invalidEmail';
    if (!_email.hasMatch(v)) return 'auth.err.invalidEmail';
    return null;
  }

  /// التحقق من الموبايل حسب الدولة.
  ///
  /// بيشيل الصفر البادئ تلقائياً (شائع جداً في مصر والخليج)
  /// وبيقارن عدد الأرقام بالمتوقع للدولة.
  static String? phone(String? value, Country country) {
    final empty = required(value);
    if (empty != null) return empty;

    final digits = normalizePhone(value!);
    if (digits.length != country.phoneDigits) return 'auth.err.invalidPhone';

    // مصر: الموبايل بيبدأ بـ 1 بعد إزالة الصفر
    if (country.code == 'EG' && !digits.startsWith('1')) {
      return 'auth.err.invalidPhone';
    }
    // السعودية: بيبدأ بـ 5
    if (country.code == 'SA' && !digits.startsWith('5')) {
      return 'auth.err.invalidPhone';
    }
    // الإمارات: بيبدأ بـ 5
    if (country.code == 'AE' && !digits.startsWith('5')) {
      return 'auth.err.invalidPhone';
    }
    return null;
  }

  /// تحويل أي صيغة مدخلة لأرقام إنجليزية بدون صفر بادئ.
  static String normalizePhone(String raw) {
    final buffer = StringBuffer();
    for (final rune in raw.runes) {
      // أرقام إنجليزية
      if (rune >= 0x30 && rune <= 0x39) {
        buffer.writeCharCode(rune);
      }
      // أرقام عربية-هندية ٠١٢٣٤٥٦٧٨٩
      else if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.writeCharCode(rune - 0x0660 + 0x30);
      }
      // أرقام فارسية ۰۱۲۳۴۵۶۷۸۹
      else if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.writeCharCode(rune - 0x06F0 + 0x30);
      }
    }
    var digits = buffer.toString();
    while (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  static String fullPhone(String raw, Country country) =>
      '${country.dialCode}${normalizePhone(raw)}';

  static String? username(String? value) {
    final empty = required(value);
    if (empty != null) return empty;
    if (!_username.hasMatch(value!.trim().toLowerCase())) {
      return 'auth.err.emptyField';
    }
    return null;
  }

  static String? displayName(String? value) {
    final empty = required(value);
    if (empty != null) return empty;
    final v = value!.trim();
    if (v.length < 2 || v.length > 40) return 'auth.err.emptyField';
    return null;
  }

  static String? otp(String? value) {
    if (value == null || value.length != 6) return 'auth.err.emptyField';
    if (!RegExp(r'^\d{6}$').hasMatch(value)) return 'auth.err.emptyField';
    return null;
  }
}
