/// صيغة كود الإتمام في الـ QR.
///
/// -----------------------------------------------------------------------------
/// ليه مش الكود لوحده؟
///
/// المستخدم ممكن يكون عنده أكتر من صفقة مفتوحة في نفس الوقت. لو الـ QR
/// فيه الكود بس، ومسح كود من غرفة تانية، الخادم هيقول «كود غلط» —
/// وده رد مضلل: الكود مش غلط، هو بتاع صفقة تانية.
///
/// فبنحط رقم الغرفة جنب الكود، والتطبيق بيقارن قبل ما يبعت. الرسالة
/// بتبقى «ده كود صفقة تانية» — وهي الحقيقة.
///
/// وده **مش تحقق أمني**. التحقق كله في الخادم:
/// الكود لازم يكون بتاع الطرف التاني في نفس الغرفة، وفيه سقف محاولات.
/// اللي هنا بيحسّن الرسالة بس.
/// -----------------------------------------------------------------------------
library;

/// البادئة ورقم الإصدار.
///
/// الإصدار موجود من دلوقتي عشان لو غيّرنا الصيغة بعدين، النسخة القديمة
/// من التطبيق تعرف تقول «حدّث التطبيق» بدل ما تفشل بصمت.
const String kTradeCodePrefix = 'GRF1';

/// نتيجة قراءة كود ممسوح.
sealed class ScanResult {
  const ScanResult();
}

/// كود سليم لنفس الغرفة.
class ScanOk extends ScanResult {
  const ScanOk(this.code);
  final String code;
}

/// كود سليم بس لغرفة تانية.
class ScanWrongRoom extends ScanResult {
  const ScanWrongRoom();
}

/// مش كود بتاعنا أصلاً — باركود منتج، رابط، أي حاجة.
class ScanNotOurs extends ScanResult {
  const ScanNotOurs();
}

/// صيغة أحدث من اللي التطبيق يعرفها.
class ScanNeedsUpdate extends ScanResult {
  const ScanNeedsUpdate();
}

/// بناء محتوى الـ QR.
String encodeTradeCode({required String matchId, required String code}) =>
    '$kTradeCodePrefix:$matchId:$code';

/// قراءة محتوى ممسوح ومقارنته بالغرفة الحالية.
ScanResult parseTradeCode(String raw, {required String expectedMatchId}) {
  final text = raw.trim();
  final parts = text.split(':');

  if (parts.length != 3) return const ScanNotOurs();

  final prefix = parts[0].toUpperCase();
  if (!prefix.startsWith('GRF')) return const ScanNotOurs();

  // بادئة بتاعتنا بس بإصدار مختلف
  if (prefix != kTradeCodePrefix) return const ScanNeedsUpdate();

  if (parts[1] != expectedMatchId) return const ScanWrongRoom();

  final code = parts[2].toUpperCase().replaceAll(RegExp('[^0-9A-Z]'), '');
  if (code.length < 6) return const ScanNotOurs();

  return ScanOk(code);
}
