import 'package:flutter/foundation.dart';

/// سياسة كلمة السر.
///
/// القاعدة الحاكمة: الطول أهم من التعقيد. كلمة سر من 16 حرف عادي
/// أقوى بكتير من 8 حروف فيها رموز — لكن أغلب المستخدمين مش هيكتبوا 16،
/// فبنطلب 10 كحد أدنى مع تنوع.
///
/// ملاحظة أمنية: كل التحقق ده تجربة استخدام فقط.
/// **التحقق الحقيقي لازم يتكرر على الخادم** — أي فحص في التطبيق
/// يقدر أي حد يتخطاه.
enum PasswordStrength { veryWeak, weak, fair, strong, veryStrong }

@immutable
class PasswordRule {
  const PasswordRule({required this.key, required this.passed});

  final String key;
  final bool passed;
}

@immutable
class PasswordCheck {
  const PasswordCheck({
    required this.rules,
    required this.strength,
    required this.score,
  });

  final List<PasswordRule> rules;
  final PasswordStrength strength;

  /// من 0 لـ 1 — لشريط القوة.
  final double score;

  bool get isAcceptable => rules.every((r) => r.passed);
}

class PasswordPolicy {
  const PasswordPolicy._();

  static const int minLength = 10;
  static const int maxLength = 128;

  /// أشهر كلمات السر المسربة — قائمة مختصرة للفحص الفوري.
  ///
  /// الفحص الحقيقي ضد قواعد التسريبات بيتم على الخادم عبر
  /// k-anonymity (إرسال أول 5 حروف من بصمة SHA-1 فقط).
  static const Set<String> _common = {
    '1234567890', 'password', 'password1', 'password123', 'qwertyuiop',
    '123456789', '12345678', 'iloveyou', 'admin123', 'welcome1',
    'letmein123', 'abc123456', 'passw0rd', 'p@ssw0rd', 'qwerty123',
    'football1', 'monkey123', 'dragon123', '1q2w3e4r5t', 'zaq12wsx',
    'ahmed123', 'mohamed123', 'mohammed1', '01000000000', '0123456789',
  };

  static PasswordCheck evaluate(
    String password, {
    String? email,
    String? displayName,
  }) {
    final lower = password.toLowerCase();

    final hasLength = password.length >= minLength && password.length <= maxLength;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasDigit = RegExp(r'[0-9]').hasMatch(password);
    final hasSymbol = RegExp(r'''[!@#$%^&*()_\-+=\[\]{};:'",.<>/?\\|`~]''')
        .hasMatch(password);

    final notCommon = password.isNotEmpty &&
        !_common.contains(lower) &&
        !_hasLongRun(password) &&
        !_isSequential(lower);

    final notPersonal = _notPersonal(lower, email: email, displayName: displayName);

    final rules = <PasswordRule>[
      PasswordRule(key: 'pw.ruleLength', passed: hasLength),
      PasswordRule(key: 'pw.ruleUpper', passed: hasUpper),
      PasswordRule(key: 'pw.ruleLower', passed: hasLower),
      PasswordRule(key: 'pw.ruleDigit', passed: hasDigit),
      PasswordRule(key: 'pw.ruleSymbol', passed: hasSymbol),
      PasswordRule(key: 'pw.ruleNoCommon', passed: notCommon),
      PasswordRule(key: 'pw.ruleNoPersonal', passed: notPersonal),
    ];

    final score = _score(password, rules);
    return PasswordCheck(
      rules: rules,
      strength: _strength(score),
      score: score,
    );
  }

  static double _score(String password, List<PasswordRule> rules) {
    if (password.isEmpty) return 0;

    // نصف الدرجة من الطول، والنص التاني من التنوع.
    final lengthScore = (password.length / 20).clamp(0.0, 1.0) * 0.5;
    final passedCount = rules.where((r) => r.passed).length;
    final varietyScore = (passedCount / rules.length) * 0.5;

    var total = lengthScore + varietyScore;

    // عقوبات
    if (_hasLongRun(password)) total -= 0.2;
    if (_isSequential(password.toLowerCase())) total -= 0.25;
    if (_common.contains(password.toLowerCase())) total = 0.05;

    return total.clamp(0.0, 1.0);
  }

  static PasswordStrength _strength(double score) {
    if (score < 0.25) return PasswordStrength.veryWeak;
    if (score < 0.45) return PasswordStrength.weak;
    if (score < 0.65) return PasswordStrength.fair;
    if (score < 0.85) return PasswordStrength.strong;
    return PasswordStrength.veryStrong;
  }

  /// تكرار نفس الحرف 3 مرات أو أكتر: aaa / 111
  static bool _hasLongRun(String value) {
    if (value.length < 3) return false;
    for (var i = 0; i + 2 < value.length; i++) {
      if (value[i] == value[i + 1] && value[i + 1] == value[i + 2]) return true;
    }
    return false;
  }

  /// تسلسل صاعد أو هابط بطول 4: 1234 / abcd / 4321
  static bool _isSequential(String value) {
    if (value.length < 4) return false;
    var asc = 1;
    var desc = 1;
    for (var i = 1; i < value.length; i++) {
      final diff = value.codeUnitAt(i) - value.codeUnitAt(i - 1);
      asc = diff == 1 ? asc + 1 : 1;
      desc = diff == -1 ? desc + 1 : 1;
      if (asc >= 4 || desc >= 4) return true;
    }
    return false;
  }

  static bool _notPersonal(
    String lowerPassword, {
    String? email,
    String? displayName,
  }) {
    if (lowerPassword.isEmpty) return false;

    final tokens = <String>[];
    if (email != null && email.contains('@')) {
      tokens.add(email.split('@').first.toLowerCase());
    }
    if (displayName != null) {
      tokens.addAll(displayName.toLowerCase().split(RegExp(r'\s+')));
    }
    tokens.add('giraffe');

    for (final token in tokens) {
      if (token.length >= 3 && lowerPassword.contains(token)) return false;
    }
    return true;
  }
}
